/* stake.js — Pick1 as Stake would build it.
   The translation that matters: Pick1 says "AI PICKS YANKEES · 74%" as a
   headline. Stake would say it as a market — two priced outcomes with the
   recommended selection highlighted — because their whole UI is built to
   get you from reading to selecting in one tap. */

const SK = {
  search: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="7" cy="7" r="4.6"/><path d="M10.5 10.5L14 14"/></svg>`,
  fire: `<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1s.6 2.4-1 4C5.2 6.8 4 8.2 4 10a4 4 0 008 0c0-1.6-.8-2.6-1.4-3.4-.4 1-1.1 1.4-1.1 1.4s.9-2.6-1.5-6.9z"/></svg>`,
  bolt: `<svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor"><path d="M9 1L3 9h4l-1 6 6-8H8z"/></svg>`,
  ticket: `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M2.5 6.5A1 1 0 013.5 5.5h13a1 1 0 011 1v1.6a2 2 0 000 3.8v1.6a1 1 0 01-1 1h-13a1 1 0 01-1-1v-1.6a2 2 0 000-3.8z"/><path d="M12 5.8v8.4" stroke-dasharray="1.6 1.8"/></svg>`,
  trophyNav: `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M6 3h8v4.5a4 4 0 01-8 0z"/><path d="M6 4H3.5v1.5A2.5 2.5 0 006 8M14 4h2.5v1.5A2.5 2.5 0 0114 8"/><path d="M10 11.5V14M7 17h6l-.5-3h-5z"/></svg>`,
  playNav: `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><circle cx="10" cy="10" r="7.5"/><path d="M8.4 7.2l4.4 2.8-4.4 2.8z"/></svg>`,
  userNav: `<svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="10" cy="6.8" r="3.1"/><path d="M4 16.6c.6-3.1 3.1-4.7 6-4.7s5.4 1.6 6 4.7"/></svg>`,
  chev: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3l5 5-5 5"/></svg>`,
};

/* Stake quotes decimal odds everywhere, so the other side needs a price too. */
function otherOdds(p) {
  return counterPrices(p).other;
}
/* Stake sets nav labels in sentence case; league acronyms stay capped. */
const sportLabel = (s) => {
  const l = SPORT[s].label;
  return l.length > 3 ? l[0] + l.slice(1).toLowerCase() : l;
};

/* ── Header ──────────────────────────────────────────────────────── */
function skHeader() {
  return `
  <div class="sk-header">
    <div class="sk-logo">PICK<b>1</b></div>
    <div class="spacer"></div>
    ${S.isPro
      ? `<div class="sk-balance"><span class="n">PREMIUM</span><span class="u">ACTIVE</span></div>`
      : `<button class="sk-btn green" data-paywall="sk_header">Upgrade</button>`}
    <div class="sk-avatar">E</div>
  </div>`;
}

/* ── Sport pills ─────────────────────────────────────────────────── */
function skPills() {
  const count = (s) => PICKS.filter((p) => p.sport === s).length;
  const pill = (key, label, n) => `
    <div class="sk-pill ${S.selectedSport === key ? "on" : ""}" data-sport="${key}">
      ${key === "all" ? I.grid : I.ball(key)}<span>${esc(label)}</span>
      <span class="ct">${n}</span>
    </div>`;
  return `<div class="sk-pills">
    ${pill("all", "All", PICKS.length)}
    ${Object.keys(SPORT).filter((s) => count(s) > 0)
      .map((s) => pill(s, sportLabel(s), count(s))).join("")}
  </div>`;
}

/* ── Event card ──────────────────────────────────────────────────── */
function skEvent(p, locked) {
  const live = p.state === "live";
  const pickedHome = p.pick === p.home;

  const top = `
    <div class="sk-event-top">
      <span class="lg">${esc(p.league)}</span>
      ${live ? `<span class="sk-live"><span class="d"></span>LIVE</span>` : ""}
      <span class="time">${live ? "2nd half" : esc(p.time || "")}</span>
    </div>`;

  const team = (name, score, dim) => `
    <div class="sk-team ${dim ? "dim" : ""}">
      ${crest(name, "small")}
      <span class="nm">${esc(shortName(name))}</span>
      ${score != null ? `<span class="sc">${score}</span>` : ""}
    </div>`;

  const odd = (name, price, isPick) => `
    <div class="sk-odd ${locked ? "locked" : isPick ? "pick" : ""}"
         ${locked ? 'data-paywall="sk_odds"' : `data-open="${p.id}"`}>
      <span class="l">${esc(shortName(name))}</span>
      <span class="v">${locked ? "—" : price}</span>
    </div>`;

  const homePrice = pickedHome ? p.odds.toFixed(2) : otherOdds(p);
  const awayPrice = pickedHome ? otherOdds(p) : p.odds.toFixed(2);

  const model = locked
    ? `<div class="sk-model locked">
         <span class="tag">MODEL</span><span>Selection hidden</span>
         <span class="pct">Upgrade</span>
       </div>
       <div class="sk-meter locked"><i style="width:100%"></i></div>`
    : `<div class="sk-model">
         <span class="tag">MODEL</span>
         <span>${esc(shortName(p.pick))} · ${esc(p.factor || "")}</span>
         <span class="pct">${p.prob}%</span>
       </div>
       <div class="sk-meter"><i style="width:${p.prob}%"></i></div>`;

  return `
  <div class="sk-event">
    ${top}
    <div class="sk-teams">
      ${team(p.away, live ? p.awayScore : null, false)}
      ${team(p.home, live ? p.homeScore : null, false)}
    </div>
    <div class="sk-odds">
      ${odd(p.away, awayPrice, !pickedHome)}
      ${odd(p.home, homePrice, pickedHome)}
    </div>
    ${model}
  </div>`;
}

/* ── Sports (home) ───────────────────────────────────────────────── */
function skHome() {
  const games = filteredToday().slice().sort((a, b) => b.prob - a.prob);
  const open = S.isPro ? games : games.slice(0, 1);
  const locked = S.isPro ? [] : games.slice(1);

  const wins = HISTORY.filter((h) => h.state === "won").length;
  const losses = HISTORY.filter((h) => h.state === "lost").length;

  return `
  ${skHeader()}
  <div class="sk-search">${SK.search}<span>Search teams, leagues</span></div>
  ${skPills()}

  <div class="sk-stats">
    <div class="sk-stat"><span class="k">LAST 30</span><span class="v">${wins}-${losses}</span></div>
    <div class="sk-stat"><span class="k">HIT RATE</span><span class="v green">${Math.round(wins / (wins + losses) * 100)}%</span></div>
    <div class="sk-stat"><span class="k">TODAY</span><span class="v">${games.length}</span></div>
  </div>

  <div class="sk-sect"><span class="ic">${SK.fire}</span><span class="t">Top model picks</span>
    <span class="link">All ${games.length}${SK.chev}</span></div>
  ${open.map((p) => skEvent(p, false)).join("")}

  ${locked.length ? `
    <div class="sk-sect" style="padding-top:10px"><span class="ic">${I.lock}</span>
      <span class="t">Premium selections</span>
      <span class="link">${locked.length} locked</span></div>
    ${locked.map((p) => skEvent(p, true)).join("")}
    <div class="sk-promo" data-paywall="sk_promo">
      <div class="t">Unlock every selection</div>
      <div class="s">The model's side and win probability on all ${games.length} events today, live tracking, and the full graded record.</div>
      <button class="sk-btn green block">Start 3 days free</button>
      <div class="fine">then $14.99/wk · day passes from $2.99 · cancel anytime</div>
    </div>` : ""}

  <div class="tail"></div>`;
}

/* ── My Picks ────────────────────────────────────────────────────── */
function skPicks() {
  const favs = favPicks();
  const row = (p) => {
    const res = { won: ["win", `+${(p.odds * 100 - 100).toFixed(0)}`],
                  lost: ["loss", "-100"],
                  live: ["open", "Live"],
                  upcoming: ["open", "Open"] }[p.state] || ["open", "Open"];
    return `
    <div class="sk-row" data-open="${p.id}">
      <div class="game">
        <div class="mu">${esc(shortName(p.away))} v ${esc(shortName(p.home))}</div>
        <div class="meta">${esc(p.league)} · ${esc(p.when || p.time || "")}</div>
      </div>
      <div class="sel">
        <div class="nm">${esc(shortName(p.pick))}</div>
        <div class="od">${p.odds.toFixed(2)}</div>
      </div>
      <div class="res ${res[0]}">${res[1]}</div>
    </div>`;
  };

  const wins = favs.filter((p) => p.state === "won").length;
  const losses = favs.filter((p) => p.state === "lost").length;
  const net = favs.filter((p) => p.state === "won").reduce((s, p) => s + p.odds * 100 - 100, 0)
            - losses * 100;

  return `
  ${skHeader()}
  <div class="sk-sect" style="padding-top:14px"><span class="ic">${SK.ticket}</span><span class="t">My picks</span></div>

  <div class="sk-stats">
    <div class="sk-stat"><span class="k">TRACKED</span><span class="v">${favs.length}</span></div>
    <div class="sk-stat"><span class="k">SETTLED</span><span class="v">${wins}-${losses}</span></div>
    <div class="sk-stat"><span class="k">FLAT $100</span>
      <span class="v ${net >= 0 ? "green" : "red"}">${net >= 0 ? "+" : ""}${net.toFixed(0)}</span></div>
  </div>

  ${favs.length ? `
    <div class="sk-table">
      <div class="sk-thead">
        <span style="flex:1">EVENT</span><span style="width:88px">SELECTION</span>
        <span style="width:62px;text-align:right">RESULT</span>
      </div>
      ${favs.map(row).join("")}
    </div>` : `
    <div class="sk-empty">
      <span class="ic">${SK.ticket}</span>
      <span class="t">No picks tracked</span>
      <span class="s">Star an event and it shows up here with its result.</span>
      <button class="sk-btn grey" data-tab="home" style="margin-top:6px">Browse events</button>
    </div>`}
  <div class="tail"></div>`;
}

/* ── Live ────────────────────────────────────────────────────────── */
function skLive() {
  const live = livePicks();
  const upcoming = PICKS.filter((p) => p.state !== "live").slice(0, 3);
  return `
  ${skHeader()}
  <div class="sk-sect" style="padding-top:14px"><span class="ic">${SK.bolt}</span>
    <span class="t">Live now</span>
    <span class="link">${live.length} event${live.length === 1 ? "" : "s"}</span></div>
  ${live.length
    ? live.map((p) => skEvent(p, false)).join("")
    : `<div class="sk-empty"><span class="ic">${SK.bolt}</span>
         <span class="t">Nothing in play</span>
         <span class="s">Live events appear here as soon as they kick off.</span>
       </div>`}

  <div class="sk-sect" style="padding-top:14px"><span class="t">Starting soon</span></div>
  ${upcoming.map((p) => skEvent(p, !S.isPro)).join("")}
  <div class="tail"></div>`;
}

/* ── Account ─────────────────────────────────────────────────────── */
function skAccount() {
  const item = (icon, label, value, extra = "") => `
    <div class="sk-item ${extra}"><span class="ic">${icon}</span>
      <span class="t">${esc(label)}</span>
      <span class="v">${value ? `<span>${esc(value)}</span>` : ""}${SK.chev}</span></div>`;

  return `
  ${skHeader()}
  <div class="sk-sect" style="padding-top:14px"><span class="ic">${SK.userNav}</span><span class="t">Account</span></div>

  <div class="sk-stats">
    <div class="sk-stat"><span class="k">PLAN</span>
      <span class="v ${S.isPro ? "green" : ""}" style="font-size:15px">${S.isPro ? "Premium" : "Free"}</span></div>
    <div class="sk-stat"><span class="k">MEMBER SINCE</span><span class="v" style="font-size:15px">Mar 2026</span></div>
  </div>

  ${!S.isPro ? `
    <div class="sk-promo" data-paywall="sk_account">
      <div class="t">Go Premium</div>
      <div class="s">Every selection unlocked, live tracking, full record. 3 days free.</div>
      <button class="sk-btn green block">Upgrade</button>
    </div>` : ""}

  <div class="sk-list">
    ${item(I.bell, "Notifications", "On")}
    ${item(I.globe, "Language", "English")}
    ${item(I.card, "Subscription", S.isPro ? "Premium" : "Free")}
    ${item(I.gift, "Invite friends", "")}
  </div>
  <div class="sk-list">
    ${item(I.shield, "Privacy & security", "")}
    ${item(I.doc, "Terms & privacy policy", "")}
    ${item(I.out, "Sign out", "", "danger")}
  </div>
  <div class="tail"></div>`;
}

/* ── Nav ─────────────────────────────────────────────────────────── */
function skNav() {
  const n = (tab, icon, label, badge) => `
    <div class="sk-navitem ${S.tab === tab ? "on" : ""}" data-tab="${tab}">
      ${badge ? `<span class="badge">${badge}</span>` : ""}
      ${icon}<span class="lbl">${label}</span>
    </div>`;
  const liveCount = livePicks().length;
  return `<div class="sk-nav">
    ${n("home", SK.trophyNav, "Sports")}
    ${n("picks", SK.ticket, "My picks")}
    ${n("live", SK.playNav, "Live", liveCount || null)}
    ${n("profile", SK.userNav, "Account")}
  </div>`;
}

window.renderStake = function () {
  const body = { home: skHome, picks: skPicks, live: skLive, profile: skAccount }[S.tab]();
  return `<div class="stake">${body}</div>${skNav()}`;
};

render();
