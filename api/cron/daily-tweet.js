// Vercel scheduled function — daily X / Twitter post of the current pick.
//
// Fires 5 minutes after the daily email send (see vercel.json). The order
// is intentional: subscribers get the pick in their inbox first, then we
// post it publicly. That way the inbox arrival is "free preview" and the
// public tweet is downstream broadcast.
//
// Posting strategy: keep tweets under 280 chars so they render full-width
// on every client (no truncation). Include the league + pick + confidence
// percentage + link back to pick1.live (with a UTM tag so we can attribute
// signups via the cron in /api/subscribe).
//
// Twitter API v2 requires OAuth 1.0a User Context for the `tweets` POST
// endpoint (app-only auth can read but not write). The four credentials
// below come from a Twitter Developer App (developer.twitter.com →
// Projects & Apps → Keys & Tokens). The cron is dormant until all four
// env vars are set — failure mode is a 500 with `twitter_not_configured`
// so we don't accidentally tweet garbage.
//
// Env vars expected:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   — same as daily-pick.js
//   CRON_SECRET                               — same Bearer auth
//   TWITTER_API_KEY                           — "Consumer Keys → API Key"
//   TWITTER_API_SECRET                        — "Consumer Keys → API Secret"
//   TWITTER_ACCESS_TOKEN                      — "Access Token and Secret → Access Token"
//   TWITTER_ACCESS_SECRET                     — "Access Token and Secret → Access Token Secret"

const crypto = require('crypto');

module.exports = async (req, res) => {
  // Cron auth — same Bearer scheme as the daily-pick send.
  const expected = process.env.CRON_SECRET;
  const auth = req.headers.authorization || '';
  const isCronRequest = expected && auth === `Bearer ${expected}`;
  const isLocal = process.env.NODE_ENV === 'development' || process.env.VERCEL_ENV === 'development';
  if (!isCronRequest && !isLocal) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const TW_KEY    = process.env.TWITTER_API_KEY;
  const TW_SECRET = process.env.TWITTER_API_SECRET;
  const TW_TOKEN  = process.env.TWITTER_ACCESS_TOKEN;
  const TW_TSEC   = process.env.TWITTER_ACCESS_SECRET;

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'supabase_not_configured' });
  }
  if (!TW_KEY || !TW_SECRET || !TW_TOKEN || !TW_TSEC) {
    return res.status(500).json({ error: 'twitter_not_configured' });
  }

  // ── Test / preview modes ──────────────────────────────────────
  // ?test=1   — use a synthetic pick (skips Supabase)
  // ?latest=1 — most recent pending pick across all dates
  // ?dry=1    — build the tweet body but DON'T actually post; returns the
  //             would-be tweet for inspection
  const isTest   = req.query?.test === '1' || req.query?.test === 'true';
  const isLatest = req.query?.latest === '1' || req.query?.latest === 'true';
  const isDry    = req.query?.dry === '1' || req.query?.dry === 'true';

  try {
    let pick;
    const today = new Date().toISOString().slice(0, 10);

    if (isTest) {
      pick = {
        sport: 'basketball', league: 'NBA',
        home_team: 'Celtics', away_team: 'Lakers',
        pick: 'Celtics −6.5', probability: 84,
        confidence: '***',
        reasoning: 'TEST — synthetic pick.',
        key_factor: 'Test send',
        game_date: today,
      };
    } else {
      const dateFilter  = isLatest ? '' : `&game_date=eq.${today}`;
      const orderClause = isLatest
        ? '&order=game_date.desc,probability.desc'
        : '&order=probability.desc';
      const pickUrl = `${SUPABASE_URL}/rest/v1/picks`
        + `?result=eq.pending`
        + dateFilter
        + `&select=sport,league,home_team,away_team,pick,probability,confidence,reasoning,key_factor,game_date`
        + orderClause
        + `&limit=1`;
      const pickResp = await fetch(pickUrl, {
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, Accept: 'application/json' },
      });
      if (!pickResp.ok) {
        const detail = await pickResp.text();
        return res.status(502).json({ error: 'supabase_fetch_failed', detail });
      }
      const picks = await pickResp.json();
      if (!Array.isArray(picks) || picks.length === 0) {
        return res.status(200).json({ ok: true, skipped: 'no_picks_today', date: today });
      }
      pick = picks[0];
    }

    // ── Compose tweet body ────────────────────────────────────────
    // Format the pick into <=280 chars. Twitter counts URLs as 23 chars
    // regardless of actual length, so the visible link can be longer.
    const tweet = formatTweet(pick);

    if (isDry) {
      return res.status(200).json({ ok: true, dry: true, tweet, char_count: tweet.length });
    }

    // ── Post via Twitter API v2 ───────────────────────────────────
    const postResult = await postTweet({
      text: tweet,
      key: TW_KEY, secret: TW_SECRET,
      token: TW_TOKEN, tokenSecret: TW_TSEC,
    });

    console.log('daily-tweet sent:', postResult);
    return res.status(200).json({
      ok: true,
      tweet,
      char_count: tweet.length,
      tweet_id: postResult?.data?.id,
    });
  } catch (err) {
    console.error('daily-tweet_fatal', err);
    return res.status(500).json({ error: 'fatal', detail: err?.message });
  }
};

// ── Tweet body composition ─────────────────────────────────────────
// Format:
//   Today's call: ${pick} (${probability}% confidence)
//
//   ${league} — ${home} vs ${away}
//
//   Wins AND misses publicly logged at pick1.live ↓
//   https://pick1.live/?utm_source=x&utm_medium=organic
function formatTweet(pick) {
  const url = 'https://pick1.live/?utm_source=x&utm_medium=organic';
  const head = `Today's call: ${pick.pick} (${pick.probability}% confidence)`;
  const matchup = `${pick.league} · ${pick.home_team} vs ${pick.away_team}`;
  const tail = `Every pick logged publicly — wins AND misses. Receipts at pick1.live ↓\n${url}`;
  // 280 char budget; URL counts as 23 in Twitter's enforced length.
  return `${head}\n\n${matchup}\n\n${tail}`;
}

// ── Twitter API v2 POST /2/tweets with OAuth 1.0a ────────────────
// We hand-roll OAuth here to avoid adding a heavy SDK dependency to the
// Vercel function (cold start matters for daily crons). Spec reference:
//   https://developer.twitter.com/en/docs/authentication/oauth-1-0a
async function postTweet({ text, key, secret, token, tokenSecret }) {
  const url = 'https://api.twitter.com/2/tweets';
  const method = 'POST';

  const oauthParams = {
    oauth_consumer_key: key,
    oauth_nonce: crypto.randomBytes(16).toString('hex'),
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp: Math.floor(Date.now() / 1000).toString(),
    oauth_token: token,
    oauth_version: '1.0',
  };

  // Per OAuth 1.0a spec: signature base string is uppercase METHOD + URL +
  // sorted, encoded params. JSON body is NOT included for /2/tweets.
  const paramString = Object.keys(oauthParams)
    .sort()
    .map(k => `${rfc3986(k)}=${rfc3986(oauthParams[k])}`)
    .join('&');
  const baseString = [
    method,
    rfc3986(url),
    rfc3986(paramString),
  ].join('&');
  const signingKey = `${rfc3986(secret)}&${rfc3986(tokenSecret)}`;
  const signature = crypto
    .createHmac('sha1', signingKey)
    .update(baseString)
    .digest('base64');
  oauthParams.oauth_signature = signature;

  const authHeader =
    'OAuth ' +
    Object.keys(oauthParams)
      .sort()
      .map(k => `${rfc3986(k)}="${rfc3986(oauthParams[k])}"`)
      .join(', ');

  const resp = await fetch(url, {
    method,
    headers: {
      Authorization: authHeader,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ text }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`twitter_api_${resp.status}: ${detail}`);
  }
  return resp.json();
}

// RFC 3986 percent-encoding — Twitter's OAuth 1.0a requires this exact
// encoding (NOT encodeURIComponent's default, which leaves some chars
// unencoded that Twitter expects encoded).
function rfc3986(str) {
  return encodeURIComponent(str)
    .replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());
}
