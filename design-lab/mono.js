/* mono.js — Betclic-style layout, zero colour.
   Soccer carries a real 1/N/2 market (draw included), everything else is
   a two-way. The model's selection is the inverted button. */

const MO = {
  search: `<svg width="17" height="17" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="7" cy="7" r="4.6"/><path d="M10.5 10.5L14 14"/></svg>`,
  star: `<svg width="14" height="14" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M10 2.5l2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4L2.2 8.2l5.4-.8z"/></svg>`,
  home: `<svg width="19" height="19" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M3 8.4L10 3l7 5.4V16a1 1 0 01-1 1h-3.5v-5h-5v5H4a1 1 0 01-1-1z"/></svg>`,
  ticket: `<svg width="19" height="19" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M2.5 6.5A1 1 0 013.5 5.5h13a1 1 0 011 1v1.6a2 2 0 000 3.8v1.6a1 1 0 01-1 1h-13a1 1 0 01-1-1v-1.6a2 2 0 000-3.8z"/><path d="M12 5.8v8.4" stroke-dasharray="1.6 1.8"/></svg>`,
  live: `<svg width="19" height="19" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><circle cx="10" cy="10" r="7.4"/><path d="M10 5.6V10l3 1.8"/></svg>`,
  user: `<svg width="19" height="19" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><circle cx="10" cy="6.8" r="3.1"/><path d="M4 16.6c.6-3.1 3.1-4.7 6-4.7s5.4 1.6 6 4.7"/></svg>`,
  chev: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3l5 5-5 5"/></svg>`,
};

/* Full 1/N/2 market: the pick keeps its real price, the other outcomes
   are priced off it by counterPrices(). */
function moPrices(p) {
  const c = counterPrices(p);
  const pickedHome = p.pick === p.home;
  return {
    home: pickedHome ? p.odds.toFixed(2) : c.other,
    away: pickedHome ? c.other : p.odds.toFixed(2),
    draw: c.draw,
    pickedHome,
  };
}

/* ── Header + sport strip ────────────────────────────────────────── */
/* The sport strip belongs to the event pages only; My picks and Account
   are not filtered by sport, so it would be dead chrome there. */
function moHeader(withStrip = true) {
  const count = (s) => PICKS.filter((p) => p.sport === s).length;
  const tab = (key, label, n) => `
    <div class="mo-tab ${S.selectedSport === key ? "on" : ""}" data-sport="${key}">
      <span>${esc(label)}</span><span class="ct">${n}</span>
    </div>`;

  return `
  <div class="mo-header">
    <div class="mo-headrow">
      <span class="mo-logo">PICK1</span>
      <span class="spacer"></span>
      ${S.isPro ? `<span class="mo-plan">PREMIUM</span>` : ""}
      <span class="mo-icon">${MO.search}</span>
      <span class="mo-avatar">E</span>
    </div>
    ${withStrip ? `<div class="mo-strip">
      ${tab("all", "All", PICKS.length)}
      ${Object.keys(SPORT).filter((s) => count(s) > 0)
        .map((s) => tab(s, sportLabel(s), count(s))).join("")}
    </div>` : ""}
  </div>`;
}

function moSect(title, n) {
  return `<div class="mo-sect"><span class="t">${esc(title)}</span>
    <span class="rule"></span>${n != null ? `<span class="n">${esc(String(n))}</span>` : ""}</div>`;
}

/* ── Event ───────────────────────────────────────────────────────── */
function moEvent(p, locked) {
  const live = p.state === "live";
  const pr = moPrices(p);
  // 1/N/2 numbers the home side first, so the rows are ordered home then
  // away to match. Only clock sports carry a live minute.
  const liveLabel = p.sport === "soccer" ? "LIVE 67'" : "LIVE";

  const team = (name, score, isPick) => `
    <div class="mo-team">
      ${crest(name, "small")}
      <span class="nm">${esc(shortName(name))}</span>
      ${score != null ? `<span class="sc">${score}</span>` : ""}
    </div>`;

  const odd = (label, price, isPick) => `
    <div class="mo-odd ${locked ? "locked" : isPick ? "pick" : ""}"
         ${locked ? 'data-paywall="mo_odds"' : `data-open="${p.id}"`}>
      <span class="l">${esc(label)}</span>
      <span class="v">${locked ? "—" : price}</span>
    </div>`;

  const market = pr.draw
    ? odd("1", pr.home, !locked && pr.pickedHome)
      + odd("N", pr.draw, false)
      + odd("2", pr.away, !locked && !pr.pickedHome)
    : odd("1", pr.home, !locked && pr.pickedHome)
      + odd("2", pr.away, !locked && !pr.pickedHome);

  const model = locked
    ? `<div class="mo-model locked">
         <span class="tag">MODEL</span><span class="sel">Locked</span>
         <span class="bar"><i style="width:100%"></i></span>
         <span class="pct">··</span>
       </div>`
    : `<div class="mo-model">
         <span class="tag">MODEL</span>
         <span class="sel">${esc(shortName(p.pick))}</span>
         <span class="bar"><i style="width:${p.prob}%"></i></span>
         <span class="pct">${p.prob}%</span>
       </div>`;

  return `
  <div class="mo-event">
    <div class="mo-ev-top">
      <span>${esc(p.league)}</span>
      ${live ? `<span class="mo-livechip"><span class="d"></span>${liveLabel}</span>` : ""}
      <span class="time">${live ? "" : esc(p.time || "")}</span>
      <span class="mo-star">${MO.star}</span>
    </div>
    <div class="mo-teams">
      ${team(p.home, live ? p.homeScore : null)}
      ${team(p.away, live ? p.awayScore : null)}
    </div>
    <div class="mo-mkt">${market}</div>
    ${model}
  </div>`;
}

/* ── Sports ──────────────────────────────────────────────────────── */
function moHome() {
  const games = filteredToday().slice().sort((a, b) => b.prob - a.prob);
  const open = S.isPro ? games : games.slice(0, 1);
  const locked = S.isPro ? [] : games.slice(1);
  const wins = HISTORY.filter((h) => h.state === "won").length;
  const losses = HISTORY.filter((h) => h.state === "lost").length;

  return `
  ${moHeader()}
  ${moSect("Model record", null)}
  <div class="mo-summary">
    <div class="mo-sum"><div class="k">LAST 30</div><div class="v">${wins}-${losses}</div></div>
    <div class="mo-sum"><div class="k">HIT RATE</div><div class="v">${Math.round(wins / (wins + losses) * 100)}%</div></div>
    <div class="mo-sum"><div class="k">TODAY</div><div class="v">${games.length}</div></div>
  </div>

  ${moSect(S.isPro ? "Today's selections" : "Free selection", open.length)}
  ${open.map((p) => moEvent(p, false)).join("")}

  ${locked.length ? `
    ${moSect("Premium selections", locked.length)}
    ${locked.map((p) => moEvent(p, true)).join("")}
    <div class="mo-promo" data-paywall="mo_promo">
      <span class="k">PICK1 PREMIUM</span>
      <div class="t">Every selection,<br>every sport.</div>
      <div class="s">The model's side and win probability on all ${games.length} events today, live tracking, and the full graded record.</div>
      <button class="mo-btn">Start 3 days free</button>
      <div class="fine">then $14.99/wk · day passes from $2.99 · cancel anytime</div>
    </div>` : ""}
  <div class="tail"></div>`;
}

/* ── My picks ────────────────────────────────────────────────────── */
function moPicks() {
  const favs = favPicks();
  const wins = favs.filter((p) => p.state === "won").length;
  const losses = favs.filter((p) => p.state === "lost").length;
  const net = favs.filter((p) => p.state === "won").reduce((s, p) => s + p.odds * 100 - 100, 0)
            - losses * 100;

  const row = (p) => {
    const out = {
      won:  [`+${(p.odds * 100 - 100).toFixed(0)}`, "WON", false],
      lost: ["−100", "LOST", true],
      live: ["·", "IN PLAY", false],
      upcoming: ["·", "OPEN", true],
    }[p.state] || ["·", "OPEN", true];
    return `
    <div class="mo-lrow ${p.state}" data-open="${p.id}">
      <div class="g">
        <div class="mu">${esc(shortName(p.away))} v ${esc(shortName(p.home))}</div>
        <div class="meta">${esc(p.league)} · ${esc(p.when || p.time || "")}</div>
      </div>
      <div class="sel">
        <div class="n">${esc(shortName(p.pick))}</div>
        <div class="o">${p.odds.toFixed(2)}</div>
      </div>
      <div class="out">
        <div class="r ${out[2] ? "dim" : ""}">${out[0]}</div>
        <div class="s">${out[1]}</div>
      </div>
    </div>`;
  };

  return `
  ${moHeader(false)}
  ${moSect("Tracked", favs.length)}
  <div class="mo-summary">
    <div class="mo-sum"><div class="k">SETTLED</div><div class="v">${wins}-${losses}</div></div>
    <div class="mo-sum"><div class="k">FLAT $100</div>
      <div class="v ${net >= 0 ? "" : "dim"}">${net >= 0 ? "+" : "−"}${Math.abs(net).toFixed(0)}</div></div>
  </div>
  ${moSect("History", null)}
  ${favs.length
    ? `<div class="mo-ledger">${favs.map(row).join("")}</div>`
    : `<div class="mo-empty"><span class="ic">${MO.ticket}</span>
         <span class="t">NOTHING TRACKED</span>
         <span class="s">Star an event and it appears here with its result.</span>
       </div>`}
  <div class="tail"></div>`;
}

/* ── Live ────────────────────────────────────────────────────────── */
function moLive() {
  const live = livePicks();
  const soon = PICKS.filter((p) => p.state !== "live").slice(0, 3);
  return `
  ${moHeader()}
  ${moSect("In play", live.length)}
  ${live.length
    ? live.map((p) => moEvent(p, false)).join("")
    : `<div class="mo-empty"><span class="ic">${MO.live}</span>
         <span class="t">NOTHING IN PLAY</span>
         <span class="s">Events appear here the moment they kick off.</span>
       </div>`}
  ${moSect("Starting soon", soon.length)}
  ${soon.map((p) => moEvent(p, !S.isPro)).join("")}
  <div class="tail"></div>`;
}

/* ── Account ─────────────────────────────────────────────────────── */
function moAccount() {
  const item = (icon, label, value, extra = "") => `
    <div class="mo-item ${extra}"><span class="ic">${icon}</span>
      <span class="t">${esc(label)}</span>
      <span class="v">${value ? `<span>${esc(value)}</span>` : ""}${MO.chev}</span></div>`;

  return `
  ${moHeader(false)}
  ${moSect("Account", null)}
  <div class="mo-summary">
    <div class="mo-sum"><div class="k">PLAN</div><div class="v" style="font-size:16px">${S.isPro ? "Premium" : "Free"}</div></div>
    <div class="mo-sum"><div class="k">MEMBER SINCE</div><div class="v" style="font-size:16px">Mar 2026</div></div>
  </div>

  ${!S.isPro ? `
    <div style="height:12px"></div>
    <div class="mo-promo" data-paywall="mo_account">
      <span class="k">UPGRADE</span>
      <div class="t">Go Premium</div>
      <div class="s">Every selection unlocked, live tracking, the full record. Three days free.</div>
      <button class="mo-btn">Upgrade</button>
    </div>` : `<div style="height:12px"></div>`}

  <div class="mo-list">
    ${item(I.bell, "Notifications", "On")}
    ${item(I.globe, "Language", "English")}
    ${item(I.card, "Subscription", S.isPro ? "Premium" : "Free")}
    ${item(I.gift, "Invite friends", "")}
  </div>
  <div class="mo-list">
    ${item(I.shield, "Privacy & security", "")}
    ${item(I.doc, "Terms & privacy policy", "")}
    ${item(I.out, "Sign out", "")}
  </div>
  <div class="tail"></div>`;
}

/* ── Nav ─────────────────────────────────────────────────────────── */
function moNav() {
  const n = (tab, icon, label, dot) => `
    <div class="mo-navitem ${S.tab === tab ? "on" : ""}" data-tab="${tab}">
      ${dot ? `<span class="dot"></span>` : ""}
      ${icon}<span class="lbl">${label}</span>
    </div>`;
  return `<div class="mo-nav">
    ${n("home", MO.home, "Sports")}
    ${n("picks", MO.ticket, "My picks")}
    ${n("live", MO.live, "Live", livePicks().length > 0)}
    ${n("profile", MO.user, "Account")}
  </div>`;
}

window.renderMono = function () {
  const body = { home: moHome, picks: moPicks, live: moLive, profile: moAccount }[S.tab]();
  return `<div class="mono">${body}</div>${moNav()}`;
};

render();
