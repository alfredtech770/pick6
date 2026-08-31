/* app.js — mock data + renderers.
   The data shape mirrors Models/Pick.swift; the render functions mirror
   the SwiftUI view bodies one-for-one so a change made here has an
   obvious counterpart in the app source. */

/* ── SF Symbol stand-ins ─────────────────────────────────────────── */
const I = {
  sparkles: `<svg width="11" height="11" viewBox="0 0 16 16" fill="currentColor"><path d="M8 0l1.6 4.6L14 6.2l-4.4 1.6L8 12.4 6.4 7.8 2 6.2l4.4-1.6zM13 10l.8 2.2 2.2.8-2.2.8L13 16l-.8-2.2-2.2-.8 2.2-.8zM3 9l.6 1.7 1.7.6-1.7.6L3 13.6l-.6-1.7L.7 11.3l1.7-.6z"/></svg>`,
  trend: `<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 11l4-4 3 3 6-6"/><path d="M10 4h4v4"/></svg>`,
  lock: `<svg width="10" height="10" viewBox="0 0 16 16" fill="currentColor"><path d="M4 7V5a4 4 0 018 0v2h1a1 1 0 011 1v6a1 1 0 01-1 1H3a1 1 0 01-1-1V8a1 1 0 011-1zm2 0h4V5a2 2 0 10-4 0z"/></svg>`,
  lockOpen: `<svg width="10" height="10" viewBox="0 0 16 16" fill="currentColor"><path d="M5 7V5a3 3 0 016 0 1 1 0 002 0 5 5 0 00-10 0v2H2a1 1 0 00-1 1v6a1 1 0 001 1h9a1 1 0 001-1V8a1 1 0 00-1-1z"/></svg>`,
  check: `<svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 8.5l3.5 3.5 7.5-8"/></svg>`,
  x: `<svg width="10" height="10" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M3 3l10 10M13 3L3 13"/></svg>`,
  chevDown: `<svg width="10" height="10" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6l5 5 5-5"/></svg>`,
  chevRight: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3l5 5-5 5"/></svg>`,
  chevLeft: `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 3L5 8l5 5"/></svg>`,
  house: `<svg width="17" height="17" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5L10 3l7 5.5V16a1 1 0 01-1 1h-3v-5H7v5H4a1 1 0 01-1-1z"/></svg>`,
  star: `<svg width="17" height="17" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><path d="M10 2.5l2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4L2.2 8.2l5.4-.8z"/></svg>`,
  person: `<svg width="17" height="17" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="10" cy="6.5" r="3.3"/><path d="M3.5 17c.6-3.4 3.3-5.2 6.5-5.2s5.9 1.8 6.5 5.2"/></svg>`,
  pencil: `<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M11.5 1.7l2.8 2.8L5 13.8 1.5 14.5l.7-3.5z"/></svg>`,
  trash: `<svg width="10" height="10" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 4h11M6 4V2.5h4V4M4 4l.7 9.5h6.6L12 4"/></svg>`,
  grid: `<svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="3" r="1.8"/><circle cx="8" cy="13" r="1.8"/><circle cx="3" cy="8" r="1.8"/><circle cx="13" cy="8" r="1.8"/></svg>`,
  bell: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7a4 4 0 118 0c0 3 1 4 1 4H3s1-1 1-4z"/><path d="M6.6 13.4a1.6 1.6 0 002.8 0"/></svg>`,
  globe: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="8" cy="8" r="6"/><path d="M2 8h12M8 2c1.8 2 1.8 10 0 12M8 2C6.2 4 6.2 12 8 14"/></svg>`,
  diamond: `<svg width="9" height="9" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1l7 7-7 7-7-7z"/></svg>`,
  circle: `<svg width="9" height="9" viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="8" r="5"/></svg>`,
  shield: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M8 1.5l5.5 2v4.2c0 3.4-2.3 5.8-5.5 6.8-3.2-1-5.5-3.4-5.5-6.8V3.5z"/></svg>`,
  card: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="1.5" y="3.5" width="13" height="9" rx="1.8"/><path d="M1.5 6.5h13"/></svg>`,
  gift: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><rect x="2" y="6.5" width="12" height="7.5" rx="1"/><path d="M1 6.5h14M8 6.5V14M8 6.5S6.5 2 4.8 3.2C3.4 4.2 5 6.5 8 6.5zM8 6.5s1.5-4.5 3.2-3.3C12.6 4.2 11 6.5 8 6.5z"/></svg>`,
  doc: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M9 1.5H4a1 1 0 00-1 1v11a1 1 0 001 1h8a1 1 0 001-1V5.5z"/><path d="M9 1.5v4h4"/></svg>`,
  out: `<svg width="15" height="15" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 14H3a1 1 0 01-1-1V3a1 1 0 011-1h3"/><path d="M10.5 11L14 8l-3.5-3M14 8H6"/></svg>`,
  hourglass: `<svg width="9" height="9" viewBox="0 0 16 16" fill="currentColor"><path d="M4 1.5h8v2L9 8l3 4.5v2H4v-2L7 8 4 3.5z"/></svg>`,
  ball: (s) => ({
    basketball: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6.2"/><path d="M8 1.8v12.4M1.8 8h12.4M3.6 3.6c2.6 2.6 2.6 6.2 0 8.8M12.4 3.6c-2.6 2.6-2.6 6.2 0 8.8"/></svg>`,
    baseball: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6.2"/><path d="M4 2.6c2 2 2.6 7.4 0 10.8M12 2.6c-2 2-2.6 7.4 0 10.8"/></svg>`,
    football: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M2 14C1 8 8 1 14 2c1 6-6 13-12 12z"/><path d="M5.5 10.5l5-5M6.5 8.5l1 1M9 6l1 1"/></svg>`,
    soccer: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.2"/><path d="M8 4.2l2.8 2-1 3.3H6.2l-1-3.3z"/></svg>`,
    hockey: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><ellipse cx="8" cy="6" rx="5.5" ry="2.2"/><path d="M2.5 6v3.5c0 1.2 2.5 2.2 5.5 2.2s5.5-1 5.5-2.2V6"/></svg>`,
    combat: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"><path d="M3 6.5A2.5 2.5 0 015.5 4h4A3.5 3.5 0 0113 7.5v3a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><path d="M3 8h10"/></svg>`,
    f1: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"><path d="M1.5 9.5l1.5-3h10l1.5 3v2h-13z"/><circle cx="4.5" cy="11.5" r="1.4"/><circle cx="11.5" cy="11.5" r="1.4"/></svg>`,
    tennis: `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6.2"/><path d="M2.4 5.6c3.4.6 5.6 2.8 6.2 6.2M13.6 5.6c-3.4.6-5.6 2.8-6.2 6.2"/></svg>`,
  }[s] || `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="8" cy="8" r="6"/></svg>`),
};

/* ── Per-sport metadata (mirrors the switch statements in the views) ─ */
const SPORT = {
  basketball: { label: "NBA",     emoji: "🏀", tint: "#2FA85B" },
  soccer:     { label: "SOCCER",  emoji: "⚽️", tint: "#3563C7" },
  football:   { label: "NFL",     emoji: "🏈", tint: "#C73535" },
  baseball:   { label: "MLB",     emoji: "⚾️", tint: "#C7852F" },
  hockey:     { label: "NHL",     emoji: "🏒", tint: "#35AEC7" },
  combat:     { label: "MMA",     emoji: "🥊", tint: "#C74A2F" },
  f1:         { label: "F1",      emoji: "🏎️", tint: "#C72F49" },
  tennis:     { label: "TENNIS",  emoji: "🎾", tint: "#2FA89B" },
};

/* ESPN crest CDN — the same source AthleteResolver/TeamLogoResolver hit. */
const LOGO = {
  "New York Yankees":   "https://a.espncdn.com/i/teamlogos/mlb/500/nyy.png",
  "Boston Red Sox":     "https://a.espncdn.com/i/teamlogos/mlb/500/bos.png",
  "Los Angeles Dodgers":"https://a.espncdn.com/i/teamlogos/mlb/500/lad.png",
  "Philadelphia Phillies":"https://a.espncdn.com/i/teamlogos/mlb/500/phi.png",
  "New York Mets":      "https://a.espncdn.com/i/teamlogos/mlb/500/nym.png",
  "Houston Astros":     "https://a.espncdn.com/i/teamlogos/mlb/500/hou.png",
  "Atlanta Braves":     "https://a.espncdn.com/i/teamlogos/mlb/500/atl.png",
  "Chicago Cubs":       "https://a.espncdn.com/i/teamlogos/mlb/500/chc.png",
  "San Diego Padres":   "https://a.espncdn.com/i/teamlogos/mlb/500/sd.png",
  "Manchester City":    "https://a.espncdn.com/i/teamlogos/soccer/500/382.png",
  "Chelsea":            "https://a.espncdn.com/i/teamlogos/soccer/500/363.png",
  "Arsenal":            "https://a.espncdn.com/i/teamlogos/soccer/500/359.png",
  "Liverpool":          "https://a.espncdn.com/i/teamlogos/soccer/500/364.png",
  "Kansas City Chiefs": "https://a.espncdn.com/i/teamlogos/nfl/500/kc.png",
  "Detroit Lions":      "https://a.espncdn.com/i/teamlogos/nfl/500/det.png",
};

/* teamShortName(_:sport:) — last word for US franchises, full for clubs */
function shortName(team) {
  const clubs = ["Manchester City", "Chelsea", "Arsenal", "Liverpool"];
  if (clubs.includes(team)) return team.replace("Manchester ", "Man ");
  const w = team.split(" ");
  return w[w.length - 1];
}

/* ── Mock slate ──────────────────────────────────────────────────── */
const PICKS = [
  { id: "p1", sport: "baseball", league: "MLB", home: "Boston Red Sox", away: "New York Yankees",
    pick: "New York Yankees", prob: 74, odds: 1.85, source: "DraftKings", time: "7:10 PM",
    state: "upcoming", factor: "Cole vs LHP splits" },
  { id: "p2", sport: "soccer", league: "EPL", home: "Chelsea", away: "Manchester City",
    pick: "Manchester City", prob: 71, odds: 1.78, source: "FanDuel", time: "12:30 PM",
    state: "live", homeScore: 0, awayScore: 2, factor: "xG differential 2.4" },
  { id: "p3", sport: "baseball", league: "MLB", home: "New York Mets", away: "Philadelphia Phillies",
    pick: "New York Mets", prob: 68, odds: 1.92, source: "DraftKings", time: "8:10 PM",
    state: "upcoming", factor: "Bullpen ERA gap" },
  { id: "p4", sport: "football", league: "NFL", home: "Detroit Lions", away: "Kansas City Chiefs",
    pick: "Kansas City Chiefs", prob: 66, odds: 1.95, source: "BetMGM", time: "8:20 PM",
    state: "upcoming", factor: "Preseason starters snap count" },
  { id: "p5", sport: "baseball", league: "MLB", home: "San Diego Padres", away: "Los Angeles Dodgers",
    pick: "Los Angeles Dodgers", prob: 64, odds: 2.05, source: "DraftKings", time: "9:40 PM",
    state: "upcoming", factor: "Road OPS +.070" },
  { id: "p6", sport: "combat", league: "UFC", home: "Field", away: "Volkanovski",
    pick: "Volkanovski", prob: 62, odds: 2.10, source: "FanDuel", time: "10:00 PM",
    state: "upcoming", factor: "Significant strike rate" },
];

/* Graded history — feeds the Latest Wins rail and the Picks tab */
const HISTORY = [
  { id: "h1", sport: "baseball", league: "MLB", home: "San Francisco Giants", away: "Los Angeles Dodgers",
    pick: "Los Angeles Dodgers", prob: 81, odds: 1.61, state: "won", homeScore: 2, awayScore: 6,
    when: "TODAY", factor: "Ohtani vs RHP" },
  { id: "h2", sport: "soccer", league: "EPL", home: "Arsenal", away: "Everton",
    pick: "Arsenal", prob: 78, odds: 1.72, state: "won", homeScore: 3, awayScore: 1,
    when: "YESTERDAY", factor: "Home xG 2.8" },
  { id: "h3", sport: "baseball", league: "MLB", home: "Houston Astros", away: "Seattle Mariners",
    pick: "Houston Astros", prob: 76, odds: 1.55, state: "won", homeScore: 5, awayScore: 3,
    when: "YESTERDAY", factor: "Framber home splits" },
  { id: "h4", sport: "baseball", league: "MLB", home: "Chicago Cubs", away: "Milwaukee Brewers",
    pick: "Chicago Cubs", prob: 69, odds: 1.88, state: "lost", homeScore: 2, awayScore: 4,
    when: "YESTERDAY", factor: "Bullpen collapse" },
  { id: "h5", sport: "soccer", league: "EPL", home: "Liverpool", away: "Brentford",
    pick: "Liverpool", prob: 74, odds: 1.80, state: "won", homeScore: 2, awayScore: 0,
    when: "2 DAYS AGO", factor: "Anfield press index" },
  { id: "h6", sport: "baseball", league: "MLB", home: "Atlanta Braves", away: "Miami Marlins",
    pick: "Atlanta Braves", prob: 72, odds: 1.90, state: "won", homeScore: 7, awayScore: 4,
    when: "2 DAYS AGO", factor: "Truist Park HR rate" },
];

/* ── App state (mirrors @State / @StateObject on Pick1HomeHiFi) ───── */
const S = {
  tab: "home",          // home | picks | live | profile
  skin: "mono",         // shipped | cardart | stake | mono
  isPro: false,         // effectiveIsPro
  selectedSport: "all", // vm.selectedSport
  menuOpen: false,      // showSportMenu
  liveOnlyFavorites: false,
  favorites: ["h1", "p2", "h4", "p1"],
};

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

/* Prices for the outcomes the model did NOT take.
   Derived from the market price of the pick, not from the model's own
   probability: the model is deliberately more confident than the market
   (that gap is the product), so pricing off it produces absurd numbers
   like a 18.80 on a side the book would hang at 5. */
function counterPrices(p) {
  const implied = 1 / p.odds;                  // market probability of the pick
  const rest = Math.max(0.06, 1 - implied);    // everything else
  const price = (q, margin) => (1 / q * margin).toFixed(2);
  if (p.sport === "soccer") {
    // A draw is shorter than the outsider when one side is favoured.
    return { draw: price(rest * 0.55, 0.97), other: price(rest * 0.45, 0.97) };
  }
  return { draw: null, other: price(rest, 0.98) };
}

/* ── Crest / TeamLogo ────────────────────────────────────────────── */
/* A team with no CDN crest (or a URL that 404s) falls back to the
   initials disc, the same way Crest does in TeamLogo.swift. */
window.crestFail = function (img) {
  const box = img.parentNode;
  box.innerHTML = `<div class="fallback">${box.dataset.initials || ""}</div>`;
};

function crest(team, size) {
  const url = LOGO[team];
  const initials = esc(shortName(team).slice(0, 3).toUpperCase());
  if (!url) return `<div class="crest ${size}"><div class="fallback">${initials}</div></div>`;
  return `<div class="crest ${size}" data-initials="${initials}">` +
         `<img src="${url}" alt="" loading="lazy" onerror="crestFail(this)"></div>`;
}

/* ══════════════════════════════════════════════════════════════════
   HOME
   ══════════════════════════════════════════════════════════════════ */
function filteredToday() {
  return PICKS.filter((p) => S.selectedSport === "all" || p.sport === S.selectedSport);
}
function topPick() {
  return filteredToday().slice().sort((a, b) => b.prob - a.prob)[0];
}

function renderHero() {
  const p = topPick();
  if (!p) {
    return `<div class="hero"><div class="hero-topbar">${logoMark()}</div>
      <div class="hero-body"><div class="hero-call">
        <div class="hero-figures"><div class="pickname">NO PICKS YET</div></div>
      </div></div></div>`;
  }
  const low = p.prob < 60;
  return `
  <div class="hero" data-open="${p.id}">
    <div class="acid"><div class="acid-ring"></div></div>
    <div class="hero-topbar">${logoMark()}<div style="width:120px;height:34px"></div></div>
    <div class="hero-body">
      <div class="hero-kicker ${low ? "low" : ""}">
        ${low ? I.trend : I.sparkles}
        <span>${low ? "TODAY'S BEST AVAILABLE LEAN" : "TODAY'S TOP MODEL PICK"}</span>
        <span class="line">LINE · ${esc(p.source.toUpperCase())}</span>
      </div>
      <div class="hero-match">
        <div class="hero-col">${crest(p.away, "big")}<div class="name">${esc(shortName(p.away).toUpperCase())}</div></div>
        <div class="hero-vs">VS</div>
        <div class="hero-col">${crest(p.home, "big")}<div class="name">${esc(shortName(p.home).toUpperCase())}</div></div>
      </div>
      <div class="hero-call">
        <div class="hero-labels"><span class="l">AI PICKS</span><span class="r">WIN PROB.</span></div>
        <div class="hero-figures">
          <div class="pickname">${esc(shortName(p.pick).toUpperCase())}</div>
          <div class="prob">${p.prob}%</div>
        </div>
        <div class="hero-return">
          <span class="k">POSSIBLE RETURN</span>
          <span class="v">$100 → $${Math.round(p.odds * 100)}</span>
        </div>
      </div>
    </div>
  </div>`;
}

function logoMark() {
  return `<div class="logo"><span class="word">PICK</span><span class="tile">1</span></div>`;
}

function renderSportDropdown() {
  const sports = Object.keys(SPORT);
  const count = (s) => PICKS.filter((p) => p.sport === s).length;
  const cur = S.selectedSport;
  const curLabel = cur === "all" ? "ALL SPORTS" : SPORT[cur].label;
  const curIcon = cur === "all" ? I.grid : I.ball(cur);

  const row = (key, label, icon, n, i) => `
    <div class="sportdrop-row ${cur === key ? "on" : ""}" data-sport="${key}"
         style="animation-delay:${i * 28}ms">
      <span class="dot">${icon}</span>
      <span class="nm">${esc(label)}</span>
      <span class="ct ${n === 0 ? "zero" : ""}">${n}</span>
      <span class="tick">${I.check}</span>
    </div>`;

  return `
  <div class="sportdrop ${S.menuOpen ? "open" : ""}">
    <div class="sportdrop-btn" data-menu-toggle>
      <span class="ic">${curIcon}</span>
      <span class="lbl">${esc(curLabel)}</span>
      <span class="chev">${I.chevDown}</span>
    </div>
    ${S.menuOpen ? `<div class="sportdrop-menu">
      ${row("all", "All sports", I.grid, PICKS.length, 0)}
      ${sports.map((s, i) => row(s, SPORT[s].label, I.ball(s), count(s), i + 1)).join("")}
    </div>` : ""}
  </div>`;
}

/* LatestWinsRail + WinReceiptCard */
function renderWinsRail() {
  const results = HISTORY.filter(
    (h) => S.selectedSport === "all" || h.sport === S.selectedSport
  );
  if (!results.length) return "";

  const card = (h) => {
    const won = h.state === "won";
    const hi = Math.max(h.homeScore, h.awayScore), lo = Math.min(h.homeScore, h.awayScore);
    return `
    <div class="receipt ${won ? "" : "loss"}">
      ${won ? "" : `<div class="miss">${I.x}<span>MISSED WIN · ${esc(h.league)}</span></div>`}
      <div class="team">${esc(shortName(h.pick).toUpperCase())}</div>
      <div class="row">
        <span class="score">${won ? `W ${hi}-${lo}` : `L ${lo}-${hi}`}</span>
        <span class="pct">${h.prob}%</span>
      </div>
      ${won ? `<div class="payout">$100 → $${Math.round(h.odds * 100)}</div>` : ""}
    </div>`;
  };

  // Free tier appends the "members won more" regret card.
  const members = !S.isPro ? `
    <div class="members" data-paywall="members_card">
      <div class="t">MEMBERS WON MORE</div>
      <div class="rec">5–1</div>
      <div class="net">$100 → +$284</div>
      <div class="cta">${I.lockOpen}<span>UNLOCK</span></div>
    </div>` : "";

  return `
  <div class="rail">
    <div class="rail-head">
      <span class="t">LATEST WINS</span>
      <span class="cta">SEE ALL</span>
    </div>
    <div class="rail-scroll">${results.map(card).join("")}${members}</div>
  </div>`;
}

/* LockedSlateCard (free) */
function lockedCard(p) {
  const s = SPORT[p.sport];
  return `
  <div class="gamecard" style="--tint:${s.tint}" data-paywall="locked_card">
    <div class="gc-top">
      <span class="league">${s.emoji} ${esc(p.league)}</span>
      <span class="time">${esc(p.time)}</span>
    </div>
    <div class="gc-body">
      ${crest(p.away, "small")}
      <div class="gc-mid">
        <div class="matchup">${esc(shortName(p.away).toUpperCase())}<span class="vs">&nbsp;&nbsp;VS&nbsp;&nbsp;</span>${esc(shortName(p.home).toUpperCase())}</div>
        <div class="hidden-pick">${I.lock}<span>AI PICK HIDDEN</span></div>
      </div>
      <div class="unlock">${I.lock}<span>UNLOCK</span></div>
    </div>
  </div>`;
}

/* ProSlateCard (pro) */
function proCard(p) {
  const s = SPORT[p.sport];
  let trailing;
  if (p.state === "live") {
    trailing = `<span class="chip-live"><span class="d"></span>LIVE · ${p.awayScore}–${p.homeScore}</span>`;
  } else if (p.state === "won") {
    trailing = `<span class="chip-won">${I.check}WON</span>`;
  } else if (p.state === "lost") {
    trailing = `<span class="chip-lost">${I.x}LOST</span>`;
  } else {
    trailing = `<span class="time">${esc(p.time)}</span>`;
  }
  return `
  <div class="gamecard pro" style="--tint:${s.tint}" data-open="${p.id}">
    <div class="gc-top"><span class="league">${s.emoji} ${esc(p.league)}</span>${trailing}</div>
    <div class="gc-body">
      ${crest(p.away, "small")}
      <div class="gc-mid">
        <div class="matchup">${esc(shortName(p.away).toUpperCase())}<span class="vs">&nbsp;&nbsp;VS&nbsp;&nbsp;</span>${esc(shortName(p.home).toUpperCase())}</div>
        <div class="ai-pick"><span class="k">AI PICKS</span><span class="v">${esc(shortName(p.pick).toUpperCase())}</span></div>
      </div>
      <div class="figures">
        <span class="pct">${p.prob}%</span>
        ${p.odds > 1 ? `<span class="ret">$100 → $${Math.round(p.odds * 100)}</span>`
                     : `<span class="conf">MODEL CONFIDENCE</span>`}
      </div>
    </div>
  </div>`;
}

function renderFreeSlate() {
  const top = topPick();
  const slate = filteredToday().filter((p) => p.id !== top?.id);
  if (!slate.length) return "";
  const shown = slate.slice(0, 3);
  return `
  <div class="slate">
    <div class="slate-head">
      <span class="t">FULL SLATE</span>
      <span class="lock">${I.lock}<span>PREMIUM</span></span>
    </div>
    ${shown.map(lockedCard).join("")}
    ${slate.length > 3 ? `<div class="slate-more">+${slate.length - 3} MORE PICKS INSIDE</div>` : ""}
  </div>`;
}

function renderUpsell() {
  return `
  <div class="upsell" data-paywall="home_upsell">
    <div class="pill">PICK1 PREMIUM</div>
    <div class="head">EVERY PICK.<br><span class="acc">EVERY SPORT.</span></div>
    <div class="body">The full board every morning, with the model's side, win probability and the numbers behind each call.</div>
    <div class="checks">
      <div class="check"><span class="tick">${I.check}</span>Every pick on every sport, unlocked</div>
      <div class="check"><span class="tick">${I.check}</span>Win probability + the key factors</div>
      <div class="check"><span class="tick">${I.check}</span>Live in-play tracking</div>
      <div class="check"><span class="tick">${I.check}</span>Full graded track record</div>
    </div>
    <div class="daypass">In a hurry? Day Pass gives you 24h for $2.99.</div>
    <div class="cta-wrap">
      <div class="cta">START 3 DAYS FREE</div>
      <div class="fine">then $14.99/wk · day passes from $2.99 · cancel anytime</div>
    </div>
  </div>`;
}

function renderHome() {
  // The card-art redesign lives in redesign.js; the lab bar switches between them.
  if (S.skin === "cardart" && window.renderHomeV2) return window.renderHomeV2();
  const slateCards = S.isPro
    ? filteredToday().map(proCard).join("")
    : "";
  return `
  <div class="scroll">
    <div style="position:relative">
      ${renderHero()}
      ${renderSportDropdown()}
    </div>
    ${renderWinsRail()}
    ${S.isPro ? `
      <div class="section-head"><span class="t">TODAY'S GAMES</span></div>
      <div class="slate" style="padding-top:10px">${slateCards || emptyToday()}</div>
    ` : `
      ${renderFreeSlate()}
      ${renderUpsell()}
    `}
    <div class="tail"></div>
  </div>`;
}

function emptyToday() {
  return `<div class="empty">
    <div class="ic">${I.grid}</div>
    <div class="t">NO GAMES TODAY</div>
    <div class="s">Nothing on the board for this sport. Check back tomorrow morning.</div>
  </div>`;
}

/* ══════════════════════════════════════════════════════════════════
   PICKS TAB — WinsView
   ══════════════════════════════════════════════════════════════════ */
function topnav(a, b, live = false, right = "") {
  return `
  <div class="topnav">
    <div class="sq ghost"></div>
    <div class="crumb">${live ? `<span class="livedot"></span>` : ""}<span class="a">${esc(a)}</span><span class="b">${esc(b)}</span></div>
    ${right || `<div class="sq ghost"></div>`}
  </div>`;
}

function pagehero(title, accent, subs, glow) {
  return `
  <div class="pagehero" style="--glow:${glow}">
    <div class="title"><span>${esc(title)}</span><span class="acc">${esc(accent)}</span></div>
    <div class="sub">${subs.map((s, i) => (i ? `<span class="sep"></span>` : "") + `<span>${esc(s)}</span>`).join("")}</div>
  </div>`;
}

function favPicks() {
  const all = [...PICKS, ...HISTORY];
  return S.favorites.map((id) => all.find((p) => p.id === id)).filter(Boolean);
}

function wonCard(p) {
  const state = p.state;
  const isFinal = state === "won" || state === "lost";
  const pickedHome = p.pick === p.home;
  const homeStrike = state === "lost" ? pickedHome : (isFinal && p.homeScore < p.awayScore);
  const awayStrike = state === "lost" ? !pickedHome : (isFinal && p.awayScore < p.homeScore);

  const tag = state === "live"
    ? `${p.league} · LIVE · Q3`
    : `${p.league} · ${p.when || "TODAY"} · ${isFinal ? "FINAL" : "UPCOMING"}`;

  const badge = {
    won:  `<span class="badge won">${I.check}WON</span>`,
    lost: `<span class="badge lost">${I.x}LOST</span>`,
    live: `<span class="badge live"><span class="d"></span>LIVE</span>`,
    upcoming: `<span class="badge upcoming">UPCOMING</span>`,
  }[state] || `<span class="badge awaiting">${I.hourglass}AWAITING</span>`;

  let score;
  if (state === "live" || isFinal) {
    score = `<div class="score ${state === "live" ? "livescore" : ""}">
      <span class="n ${homeStrike ? "mute" : ""}">${p.homeScore}</span>
      <span class="dash">–</span>
      <span class="n ${awayStrike ? "mute" : ""}">${p.awayScore}</span>
    </div>`;
  } else {
    score = `<span class="vsflat">VS</span>`;
  }

  const foot = state === "won"
    ? `<span class="money">$100 → $${Math.round(p.odds * 100)}</span>`
    : `<span class="factor">· ${esc(p.factor || p.league)}</span>`;

  return `
  <div class="woncard ${state}" data-open="${p.id}">
    <div class="wc-top"><span class="tag">${esc(tag)}</span>${badge}</div>
    <div class="teams">
      <div class="side">${crest(p.home, "small")}<span class="nm ${homeStrike ? "strike" : ""}">${esc(shortName(p.home))}</span></div>
      ${score}
      <div class="side away"><span class="nm ${awayStrike ? "strike" : ""}">${esc(shortName(p.away))}</span>${crest(p.away, "small")}</div>
    </div>
    <div class="foot">
      <span class="k">AI PICK</span>
      <span class="v">${esc(shortName(p.pick).toUpperCase())}</span>
      ${foot}
      <span class="x" data-unfav="${p.id}">${I.x}</span>
    </div>
  </div>`;
}

function renderPicks() {
  const favs = favPicks();
  return `
  <div class="scroll">
    ${topnav("YOU · ", "PICKS")}
    ${pagehero("YOUR", "PICKS.", [`${favs.length} SAVED MATCHES`, "TAP ★ TO FAVORITE"], "rgba(198,255,52,.22)")}
    <div class="fav-actions">
      <span class="count">${favs.length} MATCHES</span>
      ${favs.length ? `<span class="clear">${I.trash}<span>CLEAR ALL</span></span>` : ""}
    </div>
    ${favs.length
      ? `<div class="wonlist">${favs.map(wonCard).join("")}</div>`
      : `<div class="empty">
           <div class="ic">${I.star}</div>
           <div class="t">NO SAVED MATCHES</div>
           <div class="s">Star a match from its detail page and it lands here.</div>
           <div class="btn" data-tab="home">${I.sparkles}<span>BROWSE TODAY'S PICKS</span></div>
         </div>`}
    <div class="tail"></div>
  </div>`;
}

/* ══════════════════════════════════════════════════════════════════
   LIVE TAB — LiveView
   ══════════════════════════════════════════════════════════════════ */
function livePicks() { return PICKS.filter((p) => p.state === "live"); }

function renderLive() {
  const live = livePicks();
  const list = S.liveOnlyFavorites
    ? live.filter((p) => S.favorites.includes(p.id))
    : live;

  const body = list.length
    ? `<div class="hub-head"><span class="t">IN PLAY</span>
         <span class="meta"><span class="d"></span>${list.length} LIVE</span></div>
       <div class="wonlist">${list.map((p) => wonCard({ ...p, when: "TODAY" })).join("")}</div>`
    : `<div class="empty">
         <div class="ic">${I.ball("soccer")}</div>
         <div class="t">NOTHING LIVE</div>
         <div class="s">No games in play right now. The board fills up around first pitch.</div>
         <div class="btn" data-tab="home">${I.sparkles}<span>BROWSE TODAY'S PICKS</span></div>
       </div>`;

  return `
  <div class="scroll">
    ${topnav("NOW · ", "LIVE", live.length > 0)}
    ${pagehero("LIVE", "NOW.", [`${live.length} GAMES`, `${live.length} PICKS IN PLAY`], "rgba(255,90,54,.28)")}
    <div class="live-tabs">
      <div class="live-tab ${S.liveOnlyFavorites ? "" : "on"}" data-livetab="all">ALL LIVE</div>
      <div class="live-tab ${S.liveOnlyFavorites ? "on" : ""}" data-livetab="fav">FAVORITES</div>
    </div>
    ${body}
    <div class="tail"></div>
  </div>`;
}

/* ══════════════════════════════════════════════════════════════════
   PROFILE TAB — ProfileView
   ══════════════════════════════════════════════════════════════════ */
function settingRow(icon, title, value, extra = "") {
  return `
  <div class="setting-row ${extra}">
    <span class="ic">${icon}</span>
    <span class="t">${esc(title)}</span>
    <span class="v">${value ? `<span>${esc(value)}</span>` : ""}${I.chevRight}</span>
  </div>`;
}

function renderProfile() {
  return `
  <div class="scroll">
    ${topnav("APP · ", "PROFILE", false, `<div class="sq">${I.pencil}</div>`)}
    <div class="profile-head">
      <div class="avatar">E</div>
      <div class="profile-meta">
        <div class="nm">ETHAN</div>
        <div class="handle">ethan@milam.app</div>
        <div class="tier">${S.isPro ? I.diamond : I.circle}<span>${S.isPro ? "PREMIUM" : "FREE"}</span></div>
      </div>
    </div>

    ${!S.isPro ? `
      <div class="upgrade-banner" data-paywall="profile">
        <div>
          <div class="t">GO PREMIUM</div>
          <div class="s">Unlock every pick on every sport. 3 days free.</div>
        </div>
        <div class="go">UPGRADE</div>
      </div>
      <div style="height:18px"></div>` : ""}

    <div class="settings">
      <div>
        <div class="hub-head" style="padding-left:4px"><span class="t">ACCOUNT</span></div>
        <div class="settings-group">
          ${settingRow(I.bell, "Notifications", "ON")}
          ${settingRow(I.globe, "Language", "English")}
          ${settingRow(I.card, "Subscription", S.isPro ? "Premium" : "Free")}
          ${settingRow(I.gift, "Invite friends", "")}
        </div>
      </div>
      <div>
        <div class="hub-head" style="padding-left:4px"><span class="t">SUPPORT</span></div>
        <div class="settings-group">
          ${settingRow(I.shield, "Privacy & security", "")}
          ${settingRow(I.doc, "Terms & privacy policy", "")}
          ${settingRow(I.out, "Sign out", "", "danger")}
        </div>
      </div>
    </div>
    <div class="tail"></div>
  </div>`;
}

/* ══════════════════════════════════════════════════════════════════
   FloatingNav + root render
   ══════════════════════════════════════════════════════════════════ */
function renderNav() {
  const n = (tab, icon, label) => `
    <div class="nav-item ${S.tab === tab ? "on" : ""}" data-tab="${tab}">
      ${icon}<span class="lbl">${label}</span>
    </div>`;
  const liveCount = livePicks().length;
  return `
  <div class="nav">
    ${n("home", I.house, "Home")}
    ${n("picks", I.star, "Picks")}
    <div class="nav-item nav-live ${S.tab === "live" ? "on" : ""}" data-tab="live">
      <span class="dotwrap"><span class="halo"></span><span class="dot"></span></span>
      <span class="lbl">${liveCount > 0 ? `LIVE ${liveCount}` : "LIVE"}</span>
    </div>
    ${n("profile", I.person, "Profile")}
  </div>`;
}

function render() {
  if (S.skin === "stake" && window.renderStake) {
    // Full-shell skins replace everything, nav included.
    $("#app").innerHTML = window.renderStake();
  } else if (S.skin === "mono" && window.renderMono) {
    $("#app").innerHTML = window.renderMono();
  } else {
    const page = { home: renderHome, picks: renderPicks, live: renderLive, profile: renderProfile }[S.tab]();
    $("#app").innerHTML = `<div class="tabpage on">${page}</div>${renderNav()}`;
  }
  // Keep the lab toolbar in sync with app state.
  document.querySelectorAll("[data-lab-tab]").forEach((b) =>
    b.classList.toggle("on", b.dataset.labTab === S.tab));
  document.querySelectorAll("[data-lab-tier]").forEach((b) =>
    b.classList.toggle("on", (b.dataset.labTier === "pro") === S.isPro));
  document.querySelectorAll("[data-lab-style]").forEach((b) =>
    b.classList.toggle("on", b.dataset.labStyle === S.skin));
}

/* ── Interaction ─────────────────────────────────────────────────── */
document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-tab], [data-menu-toggle], [data-sport], [data-livetab], [data-lab-tab], [data-lab-tier], [data-lab-style], [data-unfav], [data-paywall], [data-open]");
  if (!t) {
    if (S.menuOpen) { S.menuOpen = false; render(); }
    return;
  }

  if (t.dataset.labTab)  { S.tab = t.dataset.labTab; S.menuOpen = false; return render(); }
  if (t.dataset.labTier) { S.isPro = t.dataset.labTier === "pro"; return render(); }
  if (t.dataset.labStyle) { S.skin = t.dataset.labStyle; S.menuOpen = false; return render(); }
  if (t.dataset.tab)     { S.tab = t.dataset.tab; S.menuOpen = false; return render(); }
  if (t.hasAttribute("data-menu-toggle")) { S.menuOpen = !S.menuOpen; return render(); }
  if (t.dataset.sport)   { S.selectedSport = t.dataset.sport; S.menuOpen = false; return render(); }
  if (t.dataset.livetab) { S.liveOnlyFavorites = t.dataset.livetab === "fav"; return render(); }
  if (t.dataset.unfav)   {
    e.stopPropagation();
    S.favorites = S.favorites.filter((id) => id !== t.dataset.unfav);
    return render();
  }
  if (t.dataset.paywall) { return openSheet(paywallSheet()); }
  if (t.dataset.open)    { return openSheet(detailSheet(t.dataset.open)); }
});

function openSheet(html) {
  const el = document.createElement("div");
  el.className = "sheet-scrim";
  el.innerHTML = `<div class="sheet"><div class="grabber"></div>${html}</div>`;
  el.addEventListener("click", (ev) => { if (ev.target === el) el.remove(); });
  $("#app").appendChild(el);
}

/* Detail + paywall are placeholders — the real MatchDetailView and
   PaywallScreen are ~2000 lines each and are not replicated yet. */
function detailSheet(id) {
  const p = [...PICKS, ...HISTORY].find((x) => x.id === id);
  if (!p) return "";
  const s = SPORT[p.sport];
  return `
  <div style="padding:8px 20px 20px">
    <div class="gamecard pro" style="--tint:${s.tint};margin-bottom:16px;cursor:default">
      <div class="gc-top"><span class="league">${s.emoji} ${esc(p.league)}</span><span class="time">${esc(p.time || p.when || "")}</span></div>
      <div class="gc-body">
        ${crest(p.away, "small")}
        <div class="gc-mid">
          <div class="matchup">${esc(shortName(p.away).toUpperCase())}<span class="vs">&nbsp;&nbsp;VS&nbsp;&nbsp;</span>${esc(shortName(p.home).toUpperCase())}</div>
          <div class="ai-pick"><span class="k">AI PICKS</span><span class="v">${esc(shortName(p.pick).toUpperCase())}</span></div>
        </div>
        <div class="figures"><span class="pct">${p.prob}%</span></div>
      </div>
    </div>
    <div class="empty" style="margin:0">
      <div class="t">MATCH DETAIL</div>
      <div class="s">MatchDetailView (Pick1Screens.swift:258) is not replicated yet — ask and it gets built into this file.</div>
    </div>
  </div>`;
}

function paywallSheet() {
  return `<div style="padding:8px 16px 20px">${renderUpsell()}</div>
  <div class="empty" style="margin:0 16px">
    <div class="t">PAYWALL</div>
    <div class="s">PaywallScreen (the onboarding funnel's plan cards) is not replicated yet.</div>
  </div>`;
}

render();
