// team-alerts: runs every minute from pg_cron.
//
// 1. Alerts for followed teams. Reads ESPN's public scoreboards, compares each
//    game with the state it saw last minute (game_alert_state) and, on a
//    change, notifies every user who follows one of the two teams
//    (favorite_teams) through send-push: kickoff, each score in football,
//    soccer, hockey and baseball, a close finish in basketball, and the final.
// 2. Live Activity updates. Every Lock Screen / Dynamic Island activity the
//    app started for an ESPN game ("espn|path|id|day" in live_activity_tokens)
//    gets the new score pushed to it, and is ended at the final. Before this,
//    activities only moved while the app was open.
//
// Silent on first sight of a game: the job records it and only speaks from
// the next change, so a fresh deploy never replays a whole slate.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ALT_KEY = Deno.env.get("PUSH_ALT_AUTH");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "S33MH59G79";
const KEY_ID = Deno.env.get("APNS_KEY_ID");
const APNS_KEY_P8 = Deno.env.get("APNS_AUTH_KEY");
const BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.pick1.app";

const LEAGUES: { path: string; sport: string; query?: string }[] = [
  { path: "football/nfl", sport: "football" },
  { path: "football/college-football", sport: "football", query: "&groups=80" },
  { path: "basketball/nba", sport: "basketball" },
  { path: "basketball/wnba", sport: "basketball" },
  { path: "basketball/mens-college-basketball", sport: "basketball", query: "&groups=50" },
  { path: "hockey/nhl", sport: "hockey" },
  { path: "baseball/mlb", sport: "baseball" },
  { path: "soccer/eng.1", sport: "soccer" },
  { path: "soccer/uefa.champions", sport: "soccer" },
  { path: "soccer/uefa.europa", sport: "soccer" },
  { path: "soccer/esp.1", sport: "soccer" },
  { path: "soccer/ita.1", sport: "soccer" },
  { path: "soccer/ger.1", sport: "soccer" },
  { path: "soccer/fra.1", sport: "soccer" },
  { path: "soccer/usa.1", sport: "soccer" },
  { path: "soccer/mex.1", sport: "soccer" },
];

type Side = { names: string[]; code: string; short: string; score: number | null };
type Game = {
  key: string; path: string; sport: string; state: "pre" | "in" | "post";
  detail: string; period: number; clockSeconds: number | null;
  home: Side; away: Side;
};

const norm = (s: string) =>
  s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

function etDay(offsetDays = 0): string {
  const d = new Date(Date.now() + offsetDays * 86400000);
  return d.toLocaleDateString("en-CA", { timeZone: "America/New_York" });
}

function side(c: any): Side {
  const t = c?.team ?? {};
  const names = [t.displayName, t.shortDisplayName, t.name, t.location, t.abbreviation, t.nickname]
    .filter(Boolean).map((n: string) => norm(n));
  const score = c?.score == null || c.score === "" ? null : Number(c.score);
  return { names, code: t.abbreviation ?? t.shortDisplayName ?? "", short: t.shortDisplayName ?? t.name ?? "", score: Number.isFinite(score) ? score : null };
}

const fetchErrors: string[] = [];

async function fetchLeague(path: string, sport: string, day: string, query = ""): Promise<Game[]> {
  try {
    const r = await fetch(`https://site.api.espn.com/apis/site/v2/sports/${path}/scoreboard?dates=${day.replaceAll("-", "")}&limit=1000${query}`,
      { headers: { "User-Agent": "Mozilla/5.0 (compatible; Pick1/1.0)", Accept: "application/json" } });
    if (!r.ok) { fetchErrors.push(`${path} ${r.status}`); return []; }
    const d = await r.json();
    return (d.events ?? []).flatMap((e: any) => {
      const c = e.competitions?.[0];
      const cs = c?.competitors ?? [];
      const h = cs.find((x: any) => x.homeAway === "home"), a = cs.find((x: any) => x.homeAway === "away");
      if (!h || !a) return [];
      const type = (c?.status ?? e.status)?.type ?? {};
      const st = (c?.status ?? e.status) ?? {};
      return [{
        key: `espn|${path}|${e.id}|${day}`, path, sport,
        state: type.state === "in" ? "in" : type.state === "post" ? "post" : "pre",
        detail: type.shortDetail ?? "", period: Number(st.period ?? 0),
        clockSeconds: typeof st.clock === "number" ? st.clock : null,
        home: side(h), away: side(a),
      } as Game];
    });
  } catch (e) { fetchErrors.push(`${path} ${String(e).slice(0, 80)}`); return []; }
}

function follows(team: string, s: Side): boolean {
  const t = norm(team);
  if (!t) return false;
  if (s.names.includes(t)) return true;
  const full = s.names[0] ?? "";
  return t.length >= 4 && (full.endsWith(" " + t) || full.startsWith(t + " "));
}

// ── APNs (Live Activities) ───────────────────────────────────────────────
function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
const b64url = (bytes: Uint8Array) => {
  let s = ""; for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
let cachedJwt: { jwt: string; iat: number } | null = null;
async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.iat < 3000) return cachedJwt.jwt;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(APNS_KEY_P8!), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));
  const input = `${enc({ alg: "ES256", kid: KEY_ID })}.${enc({ iss: TEAM_ID, iat: now })}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)));
  cachedJwt = { jwt: `${input}.${b64url(sig)}`, iat: now };
  return cachedJwt.jwt;
}

async function pushActivity(token: string, environment: string, payload: unknown, urgent: boolean) {
  const host = environment === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  const r = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await apnsJwt()}`,
      "apns-topic": `${BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": urgent ? "10" : "5",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, body: r.ok ? "" : await r.text() };
}

// ── Copy ─────────────────────────────────────────────────────────────────
const vs = (g: Game) => (g.sport === "soccer" ? `${g.home.code} vs ${g.away.code}` : `${g.away.code} @ ${g.home.code}`);
const line = (g: Game) => `${g.away.code} ${g.away.score ?? 0}, ${g.home.code} ${g.home.score ?? 0}`;

function alertFor(g: Game, prev: any): { title: string; body: string; tag: string } | null {
  if (!prev) return null;
  if (prev.state === "pre" && g.state === "in") {
    return { tag: "start", title: `${vs(g)} is live`, body: `${g.away.short} and ${g.home.short} just started. Tap to follow it live.` };
  }
  if (g.state === "post" && prev.state !== "post") {
    const h = g.home.score ?? 0, a = g.away.score ?? 0;
    const verdict = h === a ? "It ends level." : `${h > a ? g.home.short : g.away.short} win.`;
    return { tag: "final", title: `Final: ${line(g)}`, body: `${verdict} Tap for the box score.` };
  }
  if (g.state !== "in") return null;
  const scored = (g.home.score ?? 0) > (prev.home_score ?? 0) ? g.home : (g.away.score ?? 0) > (prev.away_score ?? 0) ? g.away : null;
  if (scored && g.sport !== "basketball") {
    const word = g.sport === "soccer" ? "Goal" : g.sport === "hockey" ? "Goal" : g.sport === "baseball" ? "Run" : "Score";
    return { tag: `score:${g.home.score}-${g.away.score}`, title: `${word}, ${scored.short}`, body: `${line(g)} · ${g.detail}` };
  }
  if (g.sport === "basketball" && g.period >= 4 && g.clockSeconds != null && g.clockSeconds <= 120
      && Math.abs((g.home.score ?? 0) - (g.away.score ?? 0)) <= 5 && !prev.sent?.close) {
    return { tag: "close", title: `Close finish: ${line(g)}`, body: `Under two minutes left. Tap to watch it live.` };
  }
  return null;
}

function contentState(g: Game, pickSide: string | null) {
  const h = g.home.score ?? 0, a = g.away.score ?? 0;
  // Hitting means ahead, not level: 0-0 is nobody's call yet.
  const hitting = pickSide === "home" ? h > a : pickSide === "away" ? a > h : false;
  const statusLine = g.state === "post" ? "FINAL" : g.detail ? `LIVE · ${g.detail}` : "LIVE";
  return { homeScore: h, awayScore: a, statusLine, pickHitting: hitting, isFinal: g.state === "post" };
}

Deno.serve(async (req: Request) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
  // pg_cron sends a shared secret kept in Vault (its other jobs only carry
  // the public anon key, which must not be enough to fire alerts).
  const auth = req.headers.get("authorization");
  let okAuth = auth === `Bearer ${SERVICE_KEY}` || (!!ALT_KEY && auth === `Bearer ${ALT_KEY}`);
  const cronSecret = req.headers.get("x-cron-secret");
  if (!okAuth && cronSecret) {
    const { data } = await supabase.rpc("team_alerts_secret");
    okAuth = typeof data === "string" && data.length > 0 && data === cronSecret;
  }
  if (!okAuth) return new Response("Unauthorized", { status: 401 });

  const [{ data: favs }, { data: tokens }] = await Promise.all([
    supabase.from("favorite_teams").select("user_id, team"),
    supabase.from("live_activity_tokens").select("token, game_id, pick_side, environment").like("game_id", "espn|%"),
  ]);
  if (!favs?.length && !tokens?.length) return Response.json({ ok: true, idle: true });

  // Late games run past midnight Eastern: read yesterday too until 4am.
  const etHour = Number(new Date().toLocaleString("en-US", { timeZone: "America/New_York", hour: "2-digit", hourCycle: "h23" }));
  const days = etHour < 4 ? [etDay(-1), etDay(0)] : [etDay(0)];
  const tokenPaths = new Set((tokens ?? []).map((t: any) => String(t.game_id).split("|")[1]));
  const leagues = favs?.length ? LEAGUES : LEAGUES.filter((l) => tokenPaths.has(l.path));
  const games = (await Promise.all(days.flatMap((d) => leagues.map((l) => fetchLeague(l.path, l.sport, d, l.query))))).flat();
  if (!games.length) return Response.json({ ok: true, games: 0, days, leagues: leagues.length, errors: fetchErrors.slice(0, 5) });

  const { data: prevRows } = await supabase.from("game_alert_state").select("*").in("event_key", games.map((g) => g.key));
  const prev = new Map((prevRows ?? []).map((r: any) => [r.event_key, r]));

  const sends: Promise<unknown>[] = [];
  const upserts: any[] = [];
  let alerts = 0, activityPushes = 0;

  for (const g of games) {
    const p = prev.get(g.key);
    const changed = !p || p.state !== g.state || p.home_score !== g.home.score || p.away_score !== g.away.score || p.detail !== g.detail;
    const sent = { ...(p?.sent ?? {}) };

    // 1. Followers
    const a = alertFor(g, p);
    if (a && !sent[a.tag]) {
      const userIds = [...new Set((favs ?? []).filter((f: any) => follows(f.team, g.home) || follows(f.team, g.away)).map((f: any) => f.user_id))];
      if (userIds.length) {
        alerts++;
        sends.push(fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_KEY}` },
          body: JSON.stringify({ title: a.title, body: a.body, userIds, prefKey: "team_alerts", data: { game: g.key, campaign: "team_alert" } }),
        }).catch(() => null));
      }
      sent[a.tag] = true;
      if (a.tag === "close") sent.close = true;
    }

    // 2. Live Activities on this game
    if (changed && p && APNS_KEY_P8 && KEY_ID) {
      for (const t of (tokens ?? []).filter((t: any) => t.game_id === g.key)) {
        const now = Math.floor(Date.now() / 1000);
        const final = g.state === "post";
        const payload = { aps: {
          timestamp: now, event: final ? "end" : "update", "content-state": contentState(g, t.pick_side),
          ...(final ? { "dismissal-date": now + 900 } : { "stale-date": now + 1800 }),
        } };
        activityPushes++;
        sends.push(pushActivity(t.token, t.environment ?? "production", payload, final || p.home_score !== g.home.score || p.away_score !== g.away.score)
          .then(async (r) => {
            // Ended or uninstalled: the token is dead, drop it.
            if (final || r.status === 410 || (r.status === 400 && r.body.includes("BadDeviceToken"))) {
              await supabase.from("live_activity_tokens").delete().eq("token", t.token);
            }
          }).catch(() => null));
      }
    }

    if (changed || a) {
      upserts.push({ event_key: g.key, state: g.state, home_score: g.home.score, away_score: g.away.score, detail: g.detail, sent, updated_at: new Date().toISOString() });
    }
  }

  if (upserts.length) await supabase.from("game_alert_state").upsert(upserts, { onConflict: "event_key" });
  await Promise.all(sends);
  // Keep the state table small: games older than three days are done.
  await supabase.from("game_alert_state").delete().lt("updated_at", new Date(Date.now() - 3 * 86400000).toISOString());
  return Response.json({ ok: true, games: games.length, alerts, activityPushes });
});
