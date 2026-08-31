/* redesign.js — the card-art home.
   Artwork for every matchup is generated, not authored: each team carries
   a primary colour, and the .art element blends the two into opposing
   washes under a halftone screen. Adding a team = adding one hex. */

const TEAM_COLOR = {
  // MLB
  "New York Yankees": "#1D3E70", "Boston Red Sox": "#BD3039",
  "Los Angeles Dodgers": "#0d5bab", "San Francisco Giants": "#FD5A1E",
  "New York Mets": "#0a3fa0", "Philadelphia Phillies": "#E81828",
  "Houston Astros": "#EB6E1F", "Seattle Mariners": "#0C5C5C",
  "Atlanta Braves": "#CE1141", "Miami Marlins": "#00A3E0",
  "Chicago Cubs": "#1144ad", "Milwaukee Brewers": "#c9a13b",
  "San Diego Padres": "#FFC425",
  // NFL
  "Kansas City Chiefs": "#E31837", "Detroit Lions": "#0076B6",
  // Soccer
  "Manchester City": "#6CABDD", "Chelsea": "#1e63c9",
  "Arsenal": "#EF0107", "Liverpool": "#C8102E",
  "Everton": "#1a49c4", "Brentford": "#E30613",
  // Combat / field events
  "Volkanovski": "#C74A2F", "Field": "#4a4e57",
};

/* Deterministic fallback so an unmapped team still gets its own colour
   rather than a grey blank — hashes the name onto a saturated hue. */
function teamColor(team) {
  if (TEAM_COLOR[team]) return TEAM_COLOR[team];
  let h = 0;
  for (let i = 0; i < team.length; i++) h = (h * 31 + team.charCodeAt(i)) % 360;
  return `hsl(${h} 62% 42%)`;
}

function artVars(p) {
  return `--away:${teamColor(p.away)};--home:${teamColor(p.home)}`;
}
const isPicked = (p, team) => p.pick === team;

/* ── Hero panel ──────────────────────────────────────────────────── */
function v2Panel(p, locked) {
  const live = p.state === "live";
  const timer = live
    ? `<span class="v2-timer live"><span class="d"></span>LIVE · ${p.awayScore}–${p.homeScore}</span>`
    : `<span class="v2-timer">${esc(p.time || "")}</span>`;

  const side = (team) => `
    <div class="side ${!locked && isPicked(p, team) ? "picked" : ""}">
      ${crest(team, "big")}
      <div class="nm">${esc(shortName(team).toUpperCase())}</div>
    </div>`;

  const call = locked
    ? `<div class="v2-call">
         <div><span class="k">AI PICK</span><span class="pick" style="color:var(--gold)">HIDDEN</span></div>
         <div class="prob"><span class="k">WIN PROB.</span><span class="n" style="color:var(--gold)">??%</span></div>
       </div>
       <div class="v2-cta gold">UNLOCK THIS PICK</div>`
    : `<div class="v2-call">
         <div><span class="k">AI PICKS</span><span class="pick">${esc(shortName(p.pick).toUpperCase())}</span></div>
         <div class="prob"><span class="k">WIN PROB.</span><span class="n">${p.prob}%</span></div>
       </div>
       <div class="v2-cta">View the breakdown · $100 → $${Math.round(p.odds * 100)}</div>`;

  return `
  <div class="v2-panel" ${locked ? 'data-paywall="hero"' : `data-open="${p.id}"`}>
    <div class="v2-panel-head">
      <span class="display">${esc(SPORT[p.sport].label)} · TOP PICK</span>
      ${timer}
    </div>
    <div class="v2-art art" style="${artVars(p)}">
      ${side(p.away)}
      <div class="vs">VS</div>
      ${side(p.home)}
    </div>
    ${call}
  </div>`;
}

/* ── Board tile ──────────────────────────────────────────────────── */
function v2Tile(p, locked) {
  const live = p.state === "live";
  const time = live
    ? `<span class="v2-tile-time live">${p.awayScore}–${p.homeScore}</span>`
    : `<span class="v2-tile-time">${esc(p.time || "")}</span>`;

  const side = (team) => `
    <div class="side ${!locked && isPicked(p, team) ? "picked" : ""}" style="position:relative">
      ${crest(team, "small")}
    </div>`;

  const foot = locked
    ? `<div style="min-width:0">
         <div class="mu">${esc(shortName(p.away).toUpperCase())} <span style="color:var(--gold)">V</span> ${esc(shortName(p.home).toUpperCase())}</div>
         <div class="sub hidden-pick">${I.lock}<span>PICK HIDDEN</span></div>
       </div>`
    : `<div style="min-width:0">
         <div class="mu">${esc(shortName(p.away).toUpperCase())} <span style="opacity:.45">V</span> ${esc(shortName(p.home).toUpperCase())}</div>
         <div class="sub">${esc(shortName(p.pick).toUpperCase())}</div>
       </div>
       <span class="pct">${p.prob}%</span>`;

  return `
  <div class="v2-tile ${locked ? "locked" : ""}" ${locked ? 'data-paywall="tile"' : `data-open="${p.id}"`}>
    <span class="v2-tile-league">${SPORT[p.sport].emoji} ${esc(p.league)}</span>
    ${time}
    ${locked ? `<span class="lockbadge">${I.lock}</span>` : ""}
    <div class="v2-tile-art art" style="${artVars(p)}">
      ${side(p.away)}<span class="vs">VS</span>${side(p.home)}
    </div>
    <div class="v2-tile-foot">${foot}</div>
  </div>`;
}

/* ── The screen ──────────────────────────────────────────────────── */
window.renderHomeV2 = function () {
  const games = filteredToday();
  const ranked = games.slice().sort((a, b) => b.prob - a.prob);
  // Free tier gets one open pick — the top one; everything else is locked.
  const heroPicks = S.isPro ? ranked.slice(0, 3) : ranked.slice(0, 1);
  const heroIds = new Set(heroPicks.map((p) => p.id));
  const board = ranked.filter((p) => !heroIds.has(p.id));

  const wins = HISTORY.filter((h) => h.state === "won").length;
  const losses = HISTORY.filter((h) => h.state === "lost").length;
  const acc = Math.round((wins / (wins + losses)) * 100);

  return `
  <div class="scroll v2">
    <div class="v2-topbar">
      <span class="display">TODAY'S BOARD</span>
      <div class="v2-chips">
        <span class="v2-chip"><span class="k">L30</span>${wins}-${losses}</span>
        <span class="v2-chip lime"><span class="k">ACC</span>${acc}%</span>
      </div>
    </div>

    <div class="v2-carousel">
      ${heroPicks.map((p) => v2Panel(p, false)).join("")}
    </div>
    ${heroPicks.length > 1 ? `<div class="v2-dots">
      ${heroPicks.map((_, i) => `<i class="${i === 0 ? "on" : ""}"></i>`).join("")}
    </div>` : `<div style="height:16px"></div>`}

    ${renderWinsRail()}

    <div class="v2-sect" style="padding-top:14px">
      <span class="display">${S.isPro ? "EVERY GAME TODAY" : "THE FULL SLATE"}</span>
      ${S.isPro
        ? `<span class="cta">${board.length} GAMES</span>`
        : `<span class="cta gold">${I.lock}<span>PREMIUM</span></span>`}
    </div>
    <div class="v2-grid">
      ${board.map((p) => v2Tile(p, !S.isPro)).join("")}
    </div>

    ${S.isPro ? "" : `
      <div class="v2-upsell" data-paywall="home_upsell">
        <span class="pill">PICK1 PREMIUM</span>
        <div class="head">EVERY PICK.<br><span class="acc">EVERY SPORT.</span></div>
        <div class="body">Unlock the model's side and win probability on all ${games.length} games today, plus live tracking and the full graded record.</div>
        <div class="v2-cta gold">START 3 DAYS FREE</div>
        <div class="fine">then $14.99/wk · day passes from $2.99 · cancel anytime</div>
      </div>`}

    <div class="tail"></div>
  </div>`;
};

/* Carousel dots follow the scroll position. */
document.addEventListener("scroll", (e) => {
  const car = e.target.closest?.(".v2-carousel");
  if (!car) return;
  const dots = car.parentNode.querySelector(".v2-dots");
  if (!dots) return;
  const i = Math.round(car.scrollLeft / (car.scrollWidth / car.children.length));
  [...dots.children].forEach((d, n) => d.classList.toggle("on", n === i));
}, true);

render();
