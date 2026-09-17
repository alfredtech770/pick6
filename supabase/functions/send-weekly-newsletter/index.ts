// Pick1 newsletter. Three issues a week (Mon, Wed, Fri at 15:00 UTC, pg_cron
// job 3), to everyone with email_preferences.newsletter = true, in their own
// language. Exactly-once per person per issue via email_log (dedupe_key is
// the issue date). Dormant until RESEND_API_KEY is set.
//
// Every issue is built from the ledger at send time, nothing is asserted:
//   1. the record since the last issue, wins and losses, net on $100 a pick
//   2. the biggest prices that landed in that window
//   3. the boldest calls on today's board (the conversion hook: the reader
//      sees what is being called and what it pays, the app has the rest)
//   4. what members tracked: how many picks they logged, how many landed,
//      and the net on the stakes THEY entered (user_bets), which is the
//      only "what our users made" figure that is honest, because it is
//      theirs and it is computed
//   5. a CTA that depends on the reader: Pro opens the board, a lapsed
//      subscriber gets the COMEBACK50 offer code, everyone else the paywall
//
// COPY RULE. No performance promise, no "place a bet". Every dollar figure
// carries its stake basis. Losing windows are sent exactly like winning ones.
// Body {cap} bounds a run (domain warming); claims past the cap are released.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
const APP_URL = "https://pick1.live";

const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

type PickRow = {
  league: string; game_date: string; home_team: string; away_team: string;
  pick: string; probability: number; result: string;
};

const matchup = (p: PickRow): string =>
  p.away_team && p.away_team.toLowerCase() !== "field"
    ? `${p.away_team} @ ${p.home_team}`
    : p.home_team;

function layout(o: {
  preheader: string; badge: string; headlineTop: string; headlineLime: string;
  bodyHtml: string; cta?: { label: string; url: string }; footerExtra?: string;
}): string {
  return `<!doctype html>
<html lang="en" dir="ltr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark only">
  <title>Pick1</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Anton&family=Archivo:wght@400;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background-color:#0a0b0d;" bgcolor="#0a0b0d">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;visibility:hidden;opacity:0;color:transparent;height:0;width:0;">${esc(o.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0a0b0d" style="background-color:#0a0b0d;">
    <tr><td align="center" style="padding:32px 16px 48px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;">
        <tr><td style="padding:0 0 20px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
            <td style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:26px;letter-spacing:0.04em;color:#f5f3ee;padding-right:8px;">PICK</td>
            <td><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
              <td bgcolor="#d4ff3a" align="center" valign="middle" style="background-color:#d4ff3a;width:30px;height:30px;border-radius:50%;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:18px;line-height:30px;color:#0a0b0d;mso-line-height-rule:exactly;">1</td>
            </tr></table></td>
          </tr></table>
        </td></tr>
        <tr><td bgcolor="#d4ff3a" style="background-color:#d4ff3a;height:4px;line-height:4px;font-size:4px;">&nbsp;</td></tr>
        <tr><td bgcolor="#101114" style="background-color:#101114;border:1px solid #22252b;border-top:0;padding:36px 32px;">
          <span style="display:inline-block;border:1px solid #d4ff3a;color:#d4ff3a;font-family:Archivo,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;padding:6px 12px;">${o.badge}</span>
          <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:42px;line-height:1.05;color:#f5f3ee;text-transform:uppercase;padding:22px 0 6px;">${o.headlineTop}<br><span style="color:#d4ff3a;">${o.headlineLime}</span></div>
          ${o.bodyHtml}
          ${o.cta ? `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 4px;"><tr>
            <td bgcolor="#d4ff3a" style="background-color:#d4ff3a;border-radius:4px;">
              <a href="${o.cta.url}" style="display:inline-block;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:17px;letter-spacing:0.06em;text-transform:uppercase;color:#0a0b0d;text-decoration:none;padding:14px 30px;">${o.cta.label}</a>
            </td></tr></table>` : ""}
        </td></tr>
        <tr><td style="padding:22px 8px 0;">
          <p style="margin:0;font-family:'Archivo Narrow','Arial Narrow',Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#6e6f75;">PICK<span style="color:#d4ff3a;">1</span>&nbsp;&middot;&nbsp;EVERY PICK, PUBLICLY LOGGED</p>
          <p style="margin:10px 0 0;font-family:Archivo,Arial,sans-serif;font-size:11px;line-height:1.6;color:#6e6f75;">AI predictions for information &amp; entertainment. Not betting advice.${o.footerExtra ?? ""}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}


type PickLite = { id: string; league: string; sport: string; game_date: string; home_team: string; away_team: string; pick: string; probability: number; result: string; market_odds: number | null };

// Profit on a $100 stake for a settled pick, real price when we have one,
// otherwise the same confidence-implied price the app prints (payoutPct).
function payout100(p: PickLite): number {
  let dec = p.market_odds && p.market_odds > 1 ? p.market_odds : 0;
  if (!dec) { const prob = Math.max(0.40, Math.min(0.90, (p.probability || 50) / 100)); dec = Math.max(1.20, 1 / prob); }
  return Math.round((dec - 1) * 100);
}

type Lang = "en" | "fr" | "es" | "de" | "it" | "pt";
const L: Record<Lang, Record<string, string>> = {
  en: { subject_up: "The board since {when}: {w}-{l}, +${net} on $100 a pick", subject_down: "The board since {when}: {w}-{l}. Every call, logged.",
        badge: "PICK1 · {date}", head_top: "THE LEDGER", head_lime: "SINCE {when}.", since: "since {when}", record: "RECORD", net: "NET ON $100 A PICK", alltime: "ALL-TIME",
        landed: "BIGGEST PRICES THAT LANDED", today: "TODAY'S BOLDEST CALLS", today_sub: "Called this morning, before kickoff. The price is the market's, the probability is the model's.",
        members: "WHAT MEMBERS TRACKED", members_line: "{n} picks logged in 7 days, {hit}% landed, {net} on the stakes members entered.", members_empty: "Track a pick in the app and your own record starts here.",
        cta_pro: "OPEN TODAY'S BOARD", cta_free: "UNLOCK EVERY PICK", comeback: "Been here before? Redeem COMEBACK50 in the app for 50% off your first month back.",
        called: "called at {p}%", pays: "pays +${pay} on $100", monday: "Friday", wednesday: "Monday", friday: "Wednesday", unsub: "Unsubscribe from the newsletter",
        foot: "AI predictions for information and entertainment. Not betting advice. Pick1 tracks picks, it never takes them. 18+." },
  fr: { subject_up: "Le tableau depuis {when} : {w}-{l}, +{net} $ sur 100 $ par pari", subject_down: "Le tableau depuis {when} : {w}-{l}. Tout est noté.",
        badge: "PICK1 · {date}", head_top: "LE REGISTRE", head_lime: "DEPUIS {when}.", since: "depuis {when}", record: "BILAN", net: "NET SUR 100 $ PAR PARI", alltime: "DEPUIS LE DÉBUT",
        landed: "LES PLUS GROSSES COTES PASSÉES", today: "LES PRONOSTICS LES PLUS AUDACIEUX DU JOUR", today_sub: "Annoncés ce matin, avant le coup d'envoi. La cote est celle du marché, la probabilité celle du modèle.",
        members: "CE QUE LES MEMBRES ONT SUIVI", members_line: "{n} picks suivis en 7 jours, {hit}% passés, {net} sur les mises saisies par les membres.", members_empty: "Suivez un pick dans l'app et votre propre bilan commence ici.",
        cta_pro: "OUVRIR LE TABLEAU DU JOUR", cta_free: "DÉBLOQUER TOUS LES PICKS", comeback: "Déjà venu ? Utilisez COMEBACK50 dans l'app pour 50 % sur votre premier mois de retour.",
        called: "annoncé à {p}%", pays: "rapporte +{pay} $ sur 100 $", monday: "vendredi", wednesday: "lundi", friday: "mercredi", unsub: "Se désabonner de la newsletter",
        foot: "Prédictions IA à titre d'information et de divertissement. Pas un conseil de pari. Pick1 suit des picks, il n'en prend jamais. 18+." },
  es: { subject_up: "El tablero desde el {when}: {w}-{l}, +${net} sobre $100 por pick", subject_down: "El tablero desde el {when}: {w}-{l}. Todo registrado.",
        badge: "PICK1 · {date}", head_top: "EL REGISTRO", head_lime: "DESDE EL {when}.", since: "desde el {when}", record: "BALANCE", net: "NETO SOBRE $100 POR PICK", alltime: "HISTÓRICO",
        landed: "LAS CUOTAS MÁS ALTAS QUE ENTRARON", today: "LOS PICKS MÁS AUDACES DE HOY", today_sub: "Anunciados esta mañana, antes del inicio. La cuota es del mercado, la probabilidad del modelo.",
        members: "LO QUE SIGUIERON LOS MIEMBROS", members_line: "{n} picks seguidos en 7 días, {hit}% entraron, {net} sobre las apuestas que registraron los miembros.", members_empty: "Sigue un pick en la app y tu propio balance empieza aquí.",
        cta_pro: "ABRIR EL TABLERO DE HOY", cta_free: "DESBLOQUEAR TODOS LOS PICKS", comeback: "¿Ya estuviste aquí? Canjea COMEBACK50 en la app y ten 50% en tu primer mes de regreso.",
        called: "anunciado al {p}%", pays: "paga +${pay} sobre $100", monday: "viernes", wednesday: "lunes", friday: "miércoles", unsub: "Cancelar la suscripción al boletín",
        foot: "Predicciones de IA con fines informativos y de entretenimiento. No es consejo de apuestas. Pick1 sigue picks, nunca los toma. 18+." },
  de: { subject_up: "Das Board seit {when}: {w}-{l}, +{net} $ auf 100 $ pro Tipp", subject_down: "Das Board seit {when}: {w}-{l}. Alles protokolliert.",
        badge: "PICK1 · {date}", head_top: "DAS REGISTER", head_lime: "SEIT {when}.", since: "seit {when}", record: "BILANZ", net: "NETTO AUF 100 $ PRO TIPP", alltime: "GESAMT",
        landed: "DIE HÖCHSTEN QUOTEN, DIE AUFGINGEN", today: "DIE MUTIGSTEN TIPPS VON HEUTE", today_sub: "Heute Morgen getippt, vor dem Anpfiff. Die Quote ist die des Marktes, die Wahrscheinlichkeit die des Modells.",
        members: "WAS MITGLIEDER VERFOLGT HABEN", members_line: "{n} Tipps in 7 Tagen verfolgt, {hit}% aufgegangen, {net} auf die von Mitgliedern eingetragenen Einsätze.", members_empty: "Verfolge einen Tipp in der App und deine eigene Bilanz beginnt hier.",
        cta_pro: "HEUTIGES BOARD ÖFFNEN", cta_free: "ALLE TIPPS FREISCHALTEN", comeback: "Schon mal hier gewesen? Löse COMEBACK50 in der App ein: 50 % auf deinen ersten Monat zurück.",
        called: "mit {p}% getippt", pays: "zahlt +{pay} $ auf 100 $", monday: "Freitag", wednesday: "Montag", friday: "Mittwoch", unsub: "Newsletter abbestellen",
        foot: "KI-Prognosen zu Informations- und Unterhaltungszwecken. Keine Wettberatung. Pick1 verfolgt Tipps, es nimmt nie welche an. 18+." },
  it: { subject_up: "Il tabellone da {when}: {w}-{l}, +{net} $ su 100 $ a pronostico", subject_down: "Il tabellone da {when}: {w}-{l}. Tutto registrato.",
        badge: "PICK1 · {date}", head_top: "IL REGISTRO", head_lime: "DA {when}.", since: "da {when}", record: "BILANCIO", net: "NETTO SU 100 $ A PRONOSTICO", alltime: "TOTALE",
        landed: "LE QUOTE PIÙ ALTE PASSATE", today: "I PRONOSTICI PIÙ AUDACI DI OGGI", today_sub: "Annunciati stamattina, prima del via. La quota è del mercato, la probabilità del modello.",
        members: "COSA HANNO SEGUITO I MEMBRI", members_line: "{n} pronostici seguiti in 7 giorni, {hit}% passati, {net} sulle puntate inserite dai membri.", members_empty: "Segui un pronostico nell'app e il tuo bilancio inizia qui.",
        cta_pro: "APRI IL TABELLONE DI OGGI", cta_free: "SBLOCCA OGNI PRONOSTICO", comeback: "Sei già stato qui? Riscatta COMEBACK50 nell'app: 50% sul primo mese di ritorno.",
        called: "dato al {p}%", pays: "paga +{pay} $ su 100 $", monday: "venerdì", wednesday: "lunedì", friday: "mercoledì", unsub: "Annulla l'iscrizione alla newsletter",
        foot: "Previsioni IA a scopo informativo e di intrattenimento. Non sono consigli di scommessa. Pick1 segue i pronostici, non li accetta mai. 18+." },
  pt: { subject_up: "O quadro desde {when}: {w}-{l}, +${net} sobre $100 por palpite", subject_down: "O quadro desde {when}: {w}-{l}. Tudo registado.",
        badge: "PICK1 · {date}", head_top: "O REGISTO", head_lime: "DESDE {when}.", since: "desde {when}", record: "BALANÇO", net: "LÍQUIDO SOBRE $100 POR PALPITE", alltime: "DESDE O INÍCIO",
        landed: "AS MAIORES COTAÇÕES QUE ENTRARAM", today: "OS PALPITES MAIS OUSADOS DE HOJE", today_sub: "Anunciados esta manhã, antes do apito. A cotação é do mercado, a probabilidade é do modelo.",
        members: "O QUE OS MEMBROS ACOMPANHARAM", members_line: "{n} palpites registados em 7 dias, {hit}% entraram, {net} sobre as apostas que os membros inseriram.", members_empty: "Acompanha um palpite na app e o teu próprio balanço começa aqui.",
        cta_pro: "ABRIR O QUADRO DE HOJE", cta_free: "DESBLOQUEAR TODOS OS PALPITES", comeback: "Já estiveste aqui? Resgata COMEBACK50 na app: 50% no teu primeiro mês de volta.",
        called: "indicado a {p}%", pays: "paga +${pay} sobre $100", monday: "sexta-feira", wednesday: "segunda-feira", friday: "quarta-feira", unsub: "Cancelar a subscrição da newsletter",
        foot: "Previsões de IA para informação e entretenimento. Não é aconselhamento de apostas. O Pick1 acompanha palpites, nunca os aceita. 18+." },
};
const fill = (t: string, a: Record<string, unknown>) => t.replace(/\{(\w+)\}/g, (_, k) => String(a[k] ?? `{${k}}`));
const money = (n: number, lang: Lang) => { const s = Math.abs(n).toLocaleString(lang); return (n < 0 ? "-" : "+") + (lang === "en" || lang === "es" || lang === "pt" ? "$" + s : s + " $"); };

const STOREFRONT_LANG: Record<string, Lang> = { FRA: "fr", BEL: "fr", CHE: "fr", MEX: "es", ESP: "es", COL: "es", CHL: "es", ARG: "es", ECU: "es", PER: "es", HND: "es", DOM: "es", URY: "es", BOL: "es", BRA: "pt", PRT: "pt", MOZ: "pt", AGO: "pt", DEU: "de", ITA: "it" };

function issueHtml(lang: Lang, o: {
  date: string; when: string; w: number; l: number; net: number; wAll: number; lAll: number;
  landed: PickLite[]; today: PickLite[]; members: { n: number; hit: number; net: number } | null;
  isPro: boolean; lapsed: boolean; unsubUrl: string;
}): string {
  const t = L[lang];
  const row = (p: PickLite, right: string) => `<tr><td style="padding:9px 0;border-bottom:1px solid #22252b;">
      <span style="font-family:Archivo,Arial,sans-serif;font-size:12px;color:#6e6f75;">${esc(p.league)} · ${esc(matchup(p as any))}</span><br>
      <span style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:16px;color:#f5f3ee;text-transform:uppercase;">${esc(p.pick)}</span>
      <span style="font-family:Archivo,Arial,sans-serif;font-size:12px;color:#b9b7b0;">&nbsp;${esc(fill(t.called, { p: Math.round(p.probability) }))}</span></td>
      <td align="right" style="padding:9px 0;border-bottom:1px solid #22252b;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:16px;color:#d4ff3a;white-space:nowrap;">${right}</td></tr>`;
  const section = (title: string, sub: string | null, rows: string) => `<p style="margin:24px 0 2px;font-family:Archivo,Arial,sans-serif;font-size:12px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;color:#d4ff3a;">${title}</p>
      ${sub ? `<p style="margin:0 0 6px;font-family:Archivo,Arial,sans-serif;font-size:12px;line-height:1.6;color:#6e6f75;">${sub}</p>` : ""}
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${rows}</table>`;
  const stat = (label: string, value: string) => `<td width="33%" bgcolor="#16181c" align="center" style="background-color:#16181c;border:1px solid #22252b;padding:16px 6px;">
      <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:28px;color:${value.startsWith("-") ? "#f5f3ee" : "#d4ff3a"};">${value}</div>
      <div style="font-family:Archivo,Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;color:#b9b7b0;padding-top:6px;">${label}</div></td>`;
  const pct = (w: number, l: number) => (w + l ? Math.round((w / (w + l)) * 100) : 0);
  const landedRows = o.landed.map((p) => row(p, `+${money(payout100(p), lang).slice(1)}`)).join("");
  const todayRows = o.today.map((p) => row(p, p.market_odds ? esc(fill(t.pays, { pay: payout100(p) })).replace(/^.*?(\+)/, "$1") : "")).join("");
  const membersLine = o.members ? fill(t.members_line, { n: o.members.n, hit: o.members.hit, net: money(o.members.net, lang) }) : t.members_empty;
  return layout({
    preheader: fill(o.net >= 0 ? t.subject_up : t.subject_down, { when: o.when, w: o.w, l: o.l, net: Math.abs(o.net).toLocaleString(lang) }),
    badge: fill(t.badge, { date: o.date }),
    headlineTop: t.head_top,
    headlineLime: fill(t.head_lime, { when: o.when.toUpperCase() }),
    bodyHtml: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:14px 0 0;"><tr>
        ${stat(t.record, `${o.w}&#8211;${o.l}`)}${stat(t.net, money(o.net, lang))}${stat(t.alltime, `${pct(o.wAll, o.lAll)}%`)}
      </tr></table>
      ${o.landed.length ? section(t.landed, null, landedRows) : ""}
      ${o.today.length ? section(t.today, t.today_sub, todayRows) : ""}
      <p style="margin:24px 0 2px;font-family:Archivo,Arial,sans-serif;font-size:12px;font-weight:700;letter-spacing:0.16em;text-transform:uppercase;color:#d4ff3a;">${t.members}</p>
      <p style="margin:0;font-family:Archivo,Arial,sans-serif;font-size:14px;line-height:1.7;color:#f5f3ee;">${esc(membersLine)}</p>
      ${o.lapsed && !o.isPro ? `<p style="margin:18px 0 0;font-family:Archivo,Arial,sans-serif;font-size:14px;line-height:1.7;color:#d4ff3a;">${esc(t.comeback)}</p>` : ""}`,
    cta: { label: o.isPro ? t.cta_pro : t.cta_free, url: APP_URL },
    footerExtra: ` ${esc(t.foot)} <a href="${o.unsubUrl}" style="color:#6e6f75;text-decoration:underline;">${esc(t.unsub)}</a>.`,
  });
}

async function confirmedUsersDetailed(): Promise<Map<string, { email: string; lastSignIn: number | null }>> {
  const out = new Map<string, { email: string; lastSignIn: number | null }>();
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    for (const u of data.users) if (u.email && u.email_confirmed_at) out.set(u.id, { email: u.email, lastSignIn: u.last_sign_in_at ? Date.parse(u.last_sign_in_at) : null });
    if (data.users.length < 1000) break;
  }
  return out;
}

// PostgREST caps an unbounded select at 1000 rows. The settled-picks table
// and email_preferences (6,981 rows on 2026-09-17) are both past that, so
// each is read in pages; the original version would have computed the
// all-time record from the first thousand picks and mailed the first
// thousand people, reporting success either way.
const PAGE = 1000;
async function allPages<T>(build: (from: number, to: number) => any): Promise<T[]> {
  const out: T[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await build(from, from + PAGE - 1);
    if (error) throw error;
    out.push(...(data ?? []));
    if (!data || data.length < PAGE) break;
  }
  return out;
}


// ── Delivery ──────────────────────────────────────────────────────────────
//
// One HTTP request per email was fine for seven subscribers and is not for
// seven thousand: at the ~3 sends a second Resend answered on 2026-09-17,
// a full run needs 40 minutes and an edge function is stopped at 400s, so
// the same first few hundred people (by user_id) would get every mailing
// and nobody else ever would. Resend's batch endpoint takes 100 emails per
// call, and the email_log claim is done 500 users at a time, so a run is
// ~150 requests and about a minute. The claim stays exactly-once: rows
// already present for (user, type, key) are skipped by the upsert.
const CLAIM = 500;
const BATCH = 100;

async function claimAll(userIds: string[], emailType: string, dedupeKey: string): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  for (let i = 0; i < userIds.length; i += CLAIM) {
    const rows = userIds.slice(i, i + CLAIM).map((user_id) => ({ user_id, email_type: emailType, dedupe_key: dedupeKey, status: "pending" }));
    const { data, error } = await db.from("email_log")
      .upsert(rows, { onConflict: "user_id,email_type,dedupe_key", ignoreDuplicates: true })
      .select("id, user_id");
    if (error) throw error;
    for (const r of data ?? []) out.set(r.user_id, r.id);
  }
  return out;
}

type Outgoing = { logId: string; email: { from: string; to: string[]; subject: string; html: string; headers: Record<string, string> } };

async function sendBatched(items: Outgoing[]): Promise<{ sent: number; failed: number }> {
  let sent = 0, failed = 0;
  for (let i = 0; i < items.length; i += BATCH) {
    const chunk = items.slice(i, i + BATCH);
    const ids = chunk.map((c) => c.logId);
    try {
      // Resend allows 2 requests a second per account. Every batch call is
      // spaced out, and a 429 is retried once after backing off, because a
      // failed batch marks a hundred people as failed for the day.
      let r: Response | null = null;
      for (let attempt = 0; attempt < 3; attempt++) {
        if (i > 0 || attempt > 0) await new Promise((res) => setTimeout(res, attempt ? 2000 : 600));
        r = await fetch("https://api.resend.com/emails/batch", {
          method: "POST",
          headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify(chunk.map((c) => c.email)),
        });
        if (r.status !== 429) break;
      }
      if (!r || !r.ok) throw new Error(`Resend ${r?.status}: ${r ? (await r.text()).slice(0, 300) : "no response"}`);
      await db.from("email_log").update({ status: "sent", sent_at: new Date().toISOString() }).in("id", ids);
      sent += chunk.length;
    } catch (e) {
      await db.from("email_log").update({ status: "failed", error: String(e).slice(0, 500) }).in("id", ids);
      failed += chunk.length;
    }
  }
  return { sent, failed };
}

Deno.serve(async (req: Request) => {
  try {
    if (!RESEND_KEY) return Response.json({ skipped: "RESEND_API_KEY not set; newsletter dormant" });
    let cap = Infinity, dryRun = false;
    try { const b = await req.json(); if (typeof b?.cap === "number" && b.cap > 0) cap = b.cap; dryRun = !!b?.dryRun; } catch { /* empty body */ }

    const now = new Date();
    const issue = now.toISOString().slice(0, 10);
    // Window since the previous issue: Monday looks back to Friday (3 days), Wednesday and Friday 2 days.
    const dow = now.getUTCDay();
    const back = dow === 1 ? 3 : 2;
    const sinceDate = new Date(now.getTime() - back * 86400000).toISOString().slice(0, 10);
    const whenKey = dow === 1 ? "monday" : dow === 3 ? "wednesday" : "friday";

    const settled = await allPages<PickLite>((from, to) => db.from("picks")
      .select("id, league, sport, game_date, home_team, away_team, pick, probability, result, market_odds")
      .in("result", ["win", "loss"]).order("game_date", { ascending: true }).order("id", { ascending: true }).range(from, to));
    if (settled.length === 0) return Response.json({ skipped: "no settled picks yet" });
    const wAll = settled.filter((p) => p.result === "win").length, lAll = settled.length - wAll;
    const win = settled.filter((p) => p.game_date >= sinceDate && p.game_date < issue);
    const w = win.filter((p) => p.result === "win").length, l = win.length - w;
    const net = win.reduce((s, p) => s + (p.result === "win" ? payout100(p) : -100), 0);
    const landed = win.filter((p) => p.result === "win" && p.market_odds && p.market_odds > 1)
      .sort((a, b) => (b.market_odds ?? 0) - (a.market_odds ?? 0)).slice(0, 3);
    const { data: todayPicks } = await db.from("picks")
      .select("id, league, sport, game_date, home_team, away_team, pick, probability, result, market_odds")
      .eq("game_date", issue).eq("result", "pending").not("market_odds", "is", null).gte("market_odds", 1.8)
      .order("market_odds", { ascending: false }).limit(3);
    const today = (todayPicks ?? []) as PickLite[];

    // What members tracked over 7 days: their own stakes, settled against the ledger.
    const weekAgo = new Date(now.getTime() - 7 * 86400000).toISOString();
    const bets = await allPages<{ stake: number; odds_at_bet: number | null; pick_id: string }>((from, to) =>
      db.from("user_bets").select("stake, odds_at_bet, pick_id").gte("created_at", weekAgo).range(from, to));
    const byId = new Map(settled.map((p) => [p.id, p]));
    let mN = 0, mHit = 0, mNet = 0;
    for (const b of bets) {
      const p = byId.get(b.pick_id); if (!p) continue;
      mN++;
      const dec = b.odds_at_bet && b.odds_at_bet > 1 ? b.odds_at_bet : (p.market_odds && p.market_odds > 1 ? p.market_odds : 1 + payout100(p) / 100);
      if (p.result === "win") { mHit++; mNet += Number(b.stake) * (dec - 1); } else mNet -= Number(b.stake);
    }
    const members = mN ? { n: mN, hit: Math.round((mHit / mN) * 100), net: Math.round(mNet) } : null;

    // Audience, with language and status.
    const prefs = await allPages<{ user_id: string; unsubscribe_token: string }>((from, to) =>
      db.from("email_preferences").select("user_id, unsubscribe_token").eq("newsletter", true).order("user_id", { ascending: true }).range(from, to));
    const users = await confirmedUsersDetailed();
    const nowIso = now.toISOString();
    const pro = new Set<string>(), everSubbed = new Set<string>();
    for (const g of await allPages<any>((f, t2) => db.from("pro_grants").select("user_id, expires_at").range(f, t2))) if (!g.expires_at || g.expires_at > nowIso) pro.add(g.user_id);
    for (const s of await allPages<any>((f, t2) => db.from("subscriptions").select("user_id, expires_date, revocation_date").not("user_id", "is", null).range(f, t2))) {
      everSubbed.add(s.user_id);
      if (s.expires_date && s.expires_date > nowIso && !s.revocation_date) pro.add(s.user_id);
    }
    const locales = new Map<string, string>();
    for (const d of await allPages<any>((f, t2) => db.from("device_tokens").select("user_id, locale").not("user_id", "is", null).range(f, t2))) if (d.user_id && d.locale && !locales.has(d.user_id)) locales.set(d.user_id, d.locale);
    const storefront = new Map<string, string>();
    for (const s of await allPages<any>((f, t2) => db.from("subscriptions").select("user_id, raw").not("user_id", "is", null).range(f, t2))) { const sf = s.raw?.transaction?.storefront; if (s.user_id && sf && !storefront.has(s.user_id)) storefront.set(s.user_id, sf); }
    const langOf = (uid: string): Lang => {
      const loc = (locales.get(uid) || "").slice(0, 2).toLowerCase();
      if (loc && loc in L) return loc as Lang;
      return STOREFRONT_LANG[storefront.get(uid) || ""] ?? "en";
    };

    // Most recently active first, so a cap reaches the people who still open the app.
    const audience = prefs.filter((p) => users.has(p.user_id))
      .sort((a, b) => (users.get(b.user_id)!.lastSignIn ?? 0) - (users.get(a.user_id)!.lastSignIn ?? 0));
    if (dryRun) {
      const sample = audience.slice(0, 3).map((p) => ({ lang: langOf(p.user_id), pro: pro.has(p.user_id), lapsed: everSubbed.has(p.user_id) && !pro.has(p.user_id) }));
      return Response.json({ dryRun: true, issue, sinceDate, record: `${w}-${l}`, net, landed: landed.map((p) => p.pick), today: today.map((p) => `${p.pick} @${p.market_odds}`), members, audience: audience.length, sample,
        subject_en: fill(net >= 0 ? L.en.subject_up : L.en.subject_down, { when: L.en[whenKey], w, l, net: Math.abs(net).toLocaleString("en") }) });
    }
    const claimed = await claimAll(audience.map((p) => p.user_id), "newsletter", issue);
    const items: Outgoing[] = [];
    for (const pref of audience) {
      const logId = claimed.get(pref.user_id); if (!logId) continue;
      const lang = langOf(pref.user_id); const t = L[lang];
      const unsubUrl = `${SUPABASE_URL}/functions/v1/email-unsubscribe?token=${pref.unsubscribe_token}&list=newsletter`;
      const when = t[whenKey];
      items.push({ logId, email: {
        from: FROM, to: [users.get(pref.user_id)!.email],
        subject: fill(net >= 0 ? t.subject_up : t.subject_down, { when, w, l, net: Math.abs(net).toLocaleString(lang) }),
        html: issueHtml(lang, { date: issue, when, w, l, net, wAll, lAll, landed, today, members, isPro: pro.has(pref.user_id), lapsed: everSubbed.has(pref.user_id) && !pro.has(pref.user_id), unsubUrl }),
        headers: { "List-Unsubscribe": `<${unsubUrl}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" },
      } });
    }
    const capped = items.length > cap ? items.slice(0, cap) : items;
    if (capped.length < items.length) await db.from("email_log").delete().in("id", items.slice(cap).map((i) => i.logId));
    const { sent, failed } = await sendBatched(capped);
    return Response.json({ sent, failed, held: items.length - capped.length, issue, record: `${w}-${l}`, net });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
