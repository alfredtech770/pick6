#!/usr/bin/env python3
"""
Pick1 — Master Tracker generator.

Produces `MASTER_TRACKER.xlsx` next to this script. Eight tabs covering
everything we measure during the 18-day pre-launch sprint, plus a
$100K scenario projection:

  1. KPI Dashboard       — top-level numbers, day-by-day
  2. Content Calendar    — what's getting posted where + perf
  3. Ad Performance      — Meta + TikTok Spark spend / CPL / conversions
  4. Channel ROI         — which channel is winning, % of total
  5. Activation Pipeline — the 11 viral activations + their state
  6. Influencer Outreach — 20-DM micro-influencer trade program
  7. Pick Performance    — daily pick record (the receipts wall data)
  8. $100K Scenario      — what the marketing spend would look like
                           with 100x the budget (street TikToks,
                           macro influencers, PR firm, etc.)

Re-run any time to regenerate from scratch:
    python3 launch/tracker/build_tracker.py

Designed so the user can drop it into Google Sheets (File → Import →
Replace spreadsheet) and have a working dashboard immediately. All tabs
have header styling + frozen header rows + conditional formatting where
helpful (CPL traffic-light, win/loss color, etc.).
"""

from datetime import date, timedelta
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import CellIsRule, ColorScaleRule
from openpyxl.utils import get_column_letter
from pathlib import Path

# ── Brand styling ────────────────────────────────────────────────────────
BRAND_BG       = "0A0B0D"
BRAND_ACCENT   = "D4FF3A"
BRAND_LINE     = "1A1D22"
BRAND_MUTED    = "9095A0"
WHITE          = "FFFFFF"

HEADER_FONT  = Font(name="Calibri", bold=True, size=11, color=BRAND_BG)
HEADER_FILL  = PatternFill("solid", fgColor=BRAND_ACCENT)
SECTION_FONT = Font(name="Calibri", bold=True, size=14, color=WHITE)
SECTION_FILL = PatternFill("solid", fgColor=BRAND_BG)
BODY_FONT    = Font(name="Calibri", size=10)
SUBTLE_FONT  = Font(name="Calibri", size=9, italic=True, color="666666")
THIN_BORDER  = Border(*[Side(style="thin", color="DDDDDD")] * 4)
CENTER       = Alignment(horizontal="center", vertical="center")
LEFT         = Alignment(horizontal="left",   vertical="center")
WRAP         = Alignment(horizontal="left",   vertical="top", wrap_text=True)


def style_header_row(ws, row, ncols):
    """Apply brand-coloured header styling to a row."""
    for c in range(1, ncols + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = CENTER
        cell.border = THIN_BORDER
    ws.row_dimensions[row].height = 24


def autosize(ws, widths):
    """Apply column widths (list of ints)."""
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w


# ── Tab 1: KPI Dashboard ─────────────────────────────────────────────────
# One row per day from May 13 (today) through May 31 (launch). The cells
# the founder will fill in nightly are: signups_total, signups_today,
# meta_spend, meta_signups, organic_signups, ig_followers, tiktok_followers,
# email_opens, email_ctr, referral_shares. Everything else (CPL, viral
# coefficient, % of target) is formulas that calculate automatically.
def build_kpi_dashboard(wb):
    ws = wb.create_sheet("1 · KPI Dashboard")
    ws.sheet_view.showGridLines = False

    # Section banner
    ws.merge_cells("A1:M1")
    ws["A1"] = "PICK1 · DAILY KPI DASHBOARD (May 13 → May 31)"
    ws["A1"].font = SECTION_FONT
    ws["A1"].fill = SECTION_FILL
    ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    # Subhead with the north-star target
    ws.merge_cells("A2:M2")
    ws["A2"] = "North Star: 1,500 waitlist signups by May 31  ·  Budget: $1,000"
    ws["A2"].font = SUBTLE_FONT
    ws["A2"].alignment = CENTER

    # Header row 3
    headers = [
        "Day", "Date", "Signups (cumulative)", "Signups (today)",
        "Meta $ today", "Meta signups today", "Meta CPL",
        "Organic signups today", "IG followers", "TikTok followers",
        "Email open %", "Referral shares", "Notes",
    ]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=3, column=c, value=h)
    style_header_row(ws, 3, len(headers))
    ws.freeze_panes = "A4"

    # Body rows — one per day
    start = date(2026, 5, 13)
    end   = date(2026, 5, 31)
    days  = (end - start).days + 1
    for i in range(days):
        d = start + timedelta(days=i)
        r = 4 + i
        ws.cell(row=r, column=1, value=f"Day {i+1}")
        ws.cell(row=r, column=2, value=d).number_format = "yyyy-mm-dd"
        # Seed today's known number (Diego = 1 cumulative on Day 1)
        if i == 0:
            ws.cell(row=r, column=3, value=1)
            ws.cell(row=r, column=4, value=1)
        # CPL formula: meta $ / meta signups (when > 0)
        ws.cell(row=r, column=7,
                value=f"=IFERROR(E{r}/F{r},\"\")").number_format = "$#,##0.00"

    # Conditional formatting — CPL traffic light
    cpl_range = f"G4:G{4 + days - 1}"
    ws.conditional_formatting.add(cpl_range,
        CellIsRule(operator="lessThan", formula=["1.5"],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add(cpl_range,
        CellIsRule(operator="between", formula=["1.5", "3"],
                   fill=PatternFill("solid", fgColor="FFEB9C")))
    ws.conditional_formatting.add(cpl_range,
        CellIsRule(operator="greaterThan", formula=["3"],
                   fill=PatternFill("solid", fgColor="FFC7CE")))

    # Cumulative signups colour scale (progress toward 1,500)
    cum_range = f"C4:C{4 + days - 1}"
    ws.conditional_formatting.add(cum_range,
        ColorScaleRule(start_type="num", start_value=0,    start_color="FFC7CE",
                       mid_type="num",   mid_value=750,    mid_color="FFEB9C",
                       end_type="num",   end_value=1500,   end_color="C6EFCE"))

    autosize(ws, [8, 12, 18, 16, 13, 18, 12, 22, 14, 18, 14, 17, 35])


# ── Tab 2: Content Calendar ──────────────────────────────────────────────
def build_content_calendar(wb):
    ws = wb.create_sheet("2 · Content Calendar")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:K1")
    ws["A1"] = "CONTENT CALENDAR — every post across every channel"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = [
        "Date", "Channel", "Format", "Pillar", "Topic / Hook",
        "Status", "URL", "Views", "Likes", "Shares", "Signups attributed",
    ]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    # Seed Day 1 content already planned
    seed_rows = [
        ("2026-05-13", "TikTok",  "Reel",     "Receipt",   "Yesterday 2-1 (SAS 126-97 lock)",       "Drafted",  "", 0, 0, 0, 0),
        ("2026-05-13", "TikTok",  "Reel",     "Daily Pick","Tonight's lock: MCI 81.2% confidence",  "Drafted",  "", 0, 0, 0, 0),
        ("2026-05-13", "IG",      "Static",   "Receipt",   "Post #2: SAS 126-97 bold static",       "To render","", 0, 0, 0, 0),
        ("2026-05-13", "IG",      "Story",    "Daily Pick","Pick locked 🔒 (link sticker)",         "Drafted",  "", 0, 0, 0, 0),
        ("2026-05-13", "Twitter", "Tweet",    "Receipt",   "Yesterday: SAS 126-97 + tonight tease", "Drafted",  "", 0, 0, 0, 0),
        ("2026-05-13", "Twitter", "Tweet",    "Daily Pick","3pm: MCI lock reveal",                  "Scheduled","", 0, 0, 0, 0),
        ("2026-05-13", "Reddit",  "Comment",  "Receipt",   "r/sportsbook daily-talk thread",        "Drafted",  "", 0, 0, 0, 0),
        ("2026-05-13", "Meta",    "Static Ad","Receipt",   "Ad 1: 'Yesterday: Spurs 126-97 ✓'",     "To render","", 0, 0, 0, 0),
        ("2026-05-13", "Meta",    "Static Ad","Daily Pick","Ad 2: 'Tonight's lock 81.2%'",          "To render","", 0, 0, 0, 0),
        ("2026-05-13", "Meta",    "Static Ad","Positioning","Ad 3: 'One pick · 9 sports'",          "To render","", 0, 0, 0, 0),
    ]
    for r, row in enumerate(seed_rows, start=3):
        for c, v in enumerate(row, start=1):
            cell = ws.cell(row=r, column=c, value=v)
            if c == 1:
                cell.number_format = "yyyy-mm-dd"

    # Status colour coding
    status_range = f"F3:F{3 + len(seed_rows) - 1 + 200}"  # room for growth
    ws.conditional_formatting.add(status_range,
        CellIsRule(operator="equal", formula=['"Posted"'],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add(status_range,
        CellIsRule(operator="equal", formula=['"Scheduled"'],
                   fill=PatternFill("solid", fgColor="FFEB9C")))
    ws.conditional_formatting.add(status_range,
        CellIsRule(operator="equal", formula=['"Drafted"'],
                   fill=PatternFill("solid", fgColor="DDEBF7")))
    ws.conditional_formatting.add(status_range,
        CellIsRule(operator="equal", formula=['"To render"'],
                   fill=PatternFill("solid", fgColor="FCE4D6")))

    autosize(ws, [12, 10, 11, 13, 42, 11, 28, 9, 9, 9, 18])


# ── Tab 3: Ad Performance ────────────────────────────────────────────────
def build_ad_performance(wb):
    ws = wb.create_sheet("3 · Ad Performance")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:J1")
    ws["A1"] = "AD PERFORMANCE — Meta + TikTok Spark, day-by-day"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = [
        "Date", "Platform", "Campaign", "Ad / Creative",
        "Spend", "Impressions", "Clicks", "CPC", "Conversions", "CPL",
    ]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    # Pre-seed Day 1 with empty Campaign 1 ad rows
    for i, ad in enumerate(["Receipts", "Lock", "Positioning"], start=3):
        ws.cell(row=i, column=1, value=date(2026, 5, 13)).number_format = "yyyy-mm-dd"
        ws.cell(row=i, column=2, value="Meta")
        ws.cell(row=i, column=3, value="LEAD-US-broad-20260513")
        ws.cell(row=i, column=4, value=f"Ad: {ad}")
        # CPC formula
        ws.cell(row=i, column=8, value=f"=IFERROR(E{i}/G{i},\"\")").number_format = "$#,##0.00"
        # CPL formula
        ws.cell(row=i, column=10, value=f"=IFERROR(E{i}/I{i},\"\")").number_format = "$#,##0.00"

    # Conditional formatting on CPL (G column → row 3 onwards)
    ws.conditional_formatting.add("J3:J500",
        CellIsRule(operator="lessThan", formula=["1.5"],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add("J3:J500",
        CellIsRule(operator="greaterThan", formula=["3"],
                   fill=PatternFill("solid", fgColor="FFC7CE")))

    autosize(ws, [12, 10, 28, 25, 10, 13, 9, 10, 13, 10])


# ── Tab 4: Channel ROI ───────────────────────────────────────────────────
def build_channel_roi(wb):
    ws = wb.create_sheet("4 · Channel ROI")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:F1")
    ws["A1"] = "CHANNEL ROI — where are signups actually coming from?"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = ["Channel", "$ Spent", "Signups", "CPL", "% of total signups", "Notes"]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    channels = ["Meta Ads (cold)", "Meta Ads (retargeting)",
                "TikTok organic", "TikTok Spark (paid boost)",
                "X / Twitter organic", "Twitter Daily Drop",
                "Instagram organic", "Instagram bio link",
                "Facebook Page organic",
                "Reddit r/SideProject", "Reddit r/giveaways",
                "Reddit r/contests", "Reddit r/sportsbook",
                "Hacker News (Show HN)", "Indie Hackers milestone",
                "LinkedIn (founder post)",
                "Influencer trades (organic)", "Influencer (paid)",
                "ProductHunt launch", "Founder essay drop",
                "Email — welcome CTA (Resend)", "Email — daily pick CTA (Resend)",
                "Email — blast to existing list",
                "Gleam sweepstakes (organic)",
                "KingSumo viral giveaway",
                "SparkLoop newsletter cross-promo",
                "Sweep aggregator submissions",
                "AI directory submissions",
                "Direct / unknown"]
    for i, ch in enumerate(channels, start=3):
        ws.cell(row=i, column=1, value=ch)
        # CPL formula
        ws.cell(row=i, column=4, value=f"=IFERROR(B{i}/C{i},\"\")").number_format = "$#,##0.00"
        # % of total — references the SUM of all signups in column C
        ws.cell(row=i, column=5,
                value=f"=IFERROR(C{i}/SUM($C$3:$C${3 + len(channels) - 1}),\"\")").number_format = "0.0%"

    autosize(ws, [28, 10, 11, 9, 20, 40])


# ── Tab 5: Activation Pipeline ───────────────────────────────────────────
def build_activations(wb):
    ws = wb.create_sheet("5 · Activations")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:F1")
    ws["A1"] = "VIRAL ACTIVATIONS — the 5 plays + status"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = ["#", "Activation", "Target launch", "Status", "Owner", "Notes"]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    activations = [
        (1, "Position-jumping referral", "Day 1 (May 13)", "LIVE",
         "Claude",
         "Every signup gets pick1.live/?r=<code>. +100 positions per ref. 3 / 10 / 25 reward tiers."),
        (2, "Public Accountability Bet", "Day 8 (May 20)", "Planned",
         "Noa",
         "'If locks lose at < 60% over 30 days, first paid month refunded.' Needs public dashboard."),
        (3, "Beat the AI challenge", "Day 18 (May 30)", "Planned",
         "Claude (build) + Noa (launch)",
         "Twitter hashtag #BeatPick1. Weekly leaderboard. Winner gets year of Pro."),
        (4, "Influencer trade program", "Day 7 (May 19)", "Planned",
         "Noa (DMs) + Claude (list)",
         "DM 20 micro-influencers (5K-100K). Full list + DM template in launch/INFLUENCER_OUTREACH.md. Free Lifetime Pro + custom ref code. Anti-spam rules included."),
        (5, "Founder story drop", "Day 14-15 (May 26-27)", "Planned",
         "Noa (record) + Claude (cross-post)",
         "Coordinated multi-platform 'how I built this' content. Twitter thread + TikTok + IG + Substack."),
        (6, "Gleam Sweepstakes (FIFA WC Tickets + Lifetime Pro)", "Day 1 (May 13)", "LIVE",
         "Claude (setup) + Noa (prize fulfillment)",
         "✅ LIVE. URL: gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro. Title + description conversion-optimized May 14 (prize-first, $1,499 value). Free tier blockers documented (Feature Media, Viral Share, Repeat Action — all Hobby+). Runs through May 31, 11:59 PM ET. Drawn live."),
        (7, "SparkLoop Newsletter Cross-Promo", "Day 8 (May 20)", "Planned",
         "Claude (apply) + auto",
         "Pay $1-2/signup for Pick1 to appear in Morning Brew / The Hustle / sports newsletters' welcome emails. Budget cap: $200 for the 18-day window. Higher LTV than Meta cold. 24-72hr approval."),
        (8, "Live Waitlist Counter on pick1.live", "Day 2 (May 14)", "LIVE",
         "Claude",
         "✅ LIVE. Public Supabase RPC get_waitlist_count() returns greatest(real_count+1, 128). Frontend fetches via /api/waitlist-count (30s edge cache + 120s SWR). Replaces Telegram (dropped — crypto/tout adjacent)."),
        (9, "Sweeps CTA in email surfaces (welcome + daily pick)", "Day 2 (May 14)", "LIVE",
         "Claude",
         "✅ LIVE. Branded sweeps CTA block embedded in (a) welcome email - every new signup sees it under the 'daily pick' panel, (b) daily-pick email - every existing subscriber sees it every morning until May 31. UTM-tagged for attribution. ~17 days of repeat exposure to existing list."),
        (10, "18-channel distribution queue (Reddit / IH / Show HN / LinkedIn)", "Day 2 (May 14)", "Drafted",
         "Claude (drafts) + Noa (post)",
         "Paste-ready posts for r/SideProject (400K), r/giveaways (1M), r/contests (100K), r/free (1M), r/sweepstakes (45K), Indie Hackers milestone, LinkedIn founder, Hacker News Show HN (Day 18 Tuesday 8am ET). See launch/DISTRIBUTION_QUEUE.md + launch/TONIGHT.md. Account-gated — Noa posts each."),
        (11, "KingSumo viral giveaway (week 2)", "Day 10 (May 22)", "Planned",
         "Claude (setup) + Noa (prize)",
         "Free-tier KingSumo, 1,000-entry cap. Prize: 10× Lifetime Pro accounts ($0 in-kind cost, $9,990 perceived value). Built-in exponential referral multiplier - each entrant's odds scale with each friend they refer. Run in parallel with Gleam."),
    ]
    for r, row in enumerate(activations, start=3):
        for c, v in enumerate(row, start=1):
            cell = ws.cell(row=r, column=c, value=v)
            if c == 6: cell.alignment = WRAP
        ws.row_dimensions[r].height = 38

    # Status colour coding
    ws.conditional_formatting.add("D3:D20",
        CellIsRule(operator="equal", formula=['"LIVE"'],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add("D3:D20",
        CellIsRule(operator="equal", formula=['"Planned"'],
                   fill=PatternFill("solid", fgColor="FFEB9C")))
    ws.conditional_formatting.add("D3:D20",
        CellIsRule(operator="equal", formula=['"Blocked"'],
                   fill=PatternFill("solid", fgColor="FFC7CE")))

    autosize(ws, [5, 32, 22, 11, 28, 55])


# ── Tab 6: Influencer Outreach ───────────────────────────────────────────
def build_influencer_outreach(wb):
    ws = wb.create_sheet("6 · Influencer Outreach")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:J1")
    ws["A1"] = "INFLUENCER OUTREACH — 20-DM micro-trade program"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = [
        "Name / Handle", "Platform", "Followers", "Niche",
        "Status", "DM sent date", "Response", "Posted?",
        "Their ref code", "Notes",
    ]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    # Pre-seed 20 blank rows for the trade program
    for i in range(20):
        ws.cell(row=3 + i, column=1, value=f"(slot {i+1})")
        ws.cell(row=3 + i, column=5, value="Cold")

    # Status colour coding
    ws.conditional_formatting.add("E3:E50",
        CellIsRule(operator="equal", formula=['"Cold"'],
                   fill=PatternFill("solid", fgColor="DDDDDD")))
    ws.conditional_formatting.add("E3:E50",
        CellIsRule(operator="equal", formula=['"DM sent"'],
                   fill=PatternFill("solid", fgColor="DDEBF7")))
    ws.conditional_formatting.add("E3:E50",
        CellIsRule(operator="equal", formula=['"Responded"'],
                   fill=PatternFill("solid", fgColor="FFEB9C")))
    ws.conditional_formatting.add("E3:E50",
        CellIsRule(operator="equal", formula=['"Posted"'],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add("E3:E50",
        CellIsRule(operator="equal", formula=['"Declined"'],
                   fill=PatternFill("solid", fgColor="FFC7CE")))

    autosize(ws, [24, 11, 11, 22, 11, 13, 26, 9, 17, 30])


# ── Tab 7: Pick Performance ──────────────────────────────────────────────
def build_pick_performance(wb):
    ws = wb.create_sheet("7 · Pick Performance")
    ws.sheet_view.showGridLines = False

    ws.merge_cells("A1:I1")
    ws["A1"] = "PICK PERFORMANCE — daily record (the receipts wall)"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    headers = [
        "Date", "League", "Game", "Pick", "Probability",
        "Tier", "Result", "1u P&L", "Notes",
    ]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=2, column=c, value=h)
    style_header_row(ws, 2, len(headers))
    ws.freeze_panes = "A3"

    # Seed yesterday + today's picks (what's already in Supabase)
    picks = [
        (date(2026, 5, 12), "NBA", "SAS vs MIN G5",   "San Antonio Spurs",      78.6, "**",  "WIN",     "+0.91", "Series 3-2 SAS"),
        (date(2026, 5, 12), "NHL", "VGK @ ANA G5",    "Vegas Golden Knights",   57.7, "*",   "WIN",     "+0.91", "Tied series winner"),
        (date(2026, 5, 12), "NHL", "MTL vs BUF G4",   "Montreal Canadiens",     56.1, "*",   "LOSS",    "-1.00", "Missed G4"),
        (date(2026, 5, 13), "EPL", "MCI vs CRY",      "Manchester City",        81.2, "***", "Pending", "",      "Lock of the night"),
        (date(2026, 5, 13), "NHL", "COL @ MIN G5",    "Colorado Avalanche",     63.6, "**",  "Pending", "",      "Series closeout"),
        (date(2026, 5, 13), "NBA", "DET vs CLE G5",   "Detroit Pistons",        60.6, "*",   "Pending", "",      "Tied series G5"),
        (date(2026, 5, 13), "NHL", "MTL vs BUF G4",   "Montreal Canadiens",     56.1, "*",   "Pending", "",      "Carryover"),
        (date(2026, 5, 13), "NHL", "VGK @ ANA G5",    "Vegas Golden Knights",   57.7, "*",   "Pending", "",      "Carryover"),
    ]
    for r, p in enumerate(picks, start=3):
        for c, v in enumerate(p, start=1):
            cell = ws.cell(row=r, column=c, value=v)
            if c == 1: cell.number_format = "yyyy-mm-dd"
            if c == 5: cell.number_format = "0.0%"

    # Result coloring
    ws.conditional_formatting.add("G3:G500",
        CellIsRule(operator="equal", formula=['"WIN"'],
                   fill=PatternFill("solid", fgColor="C6EFCE")))
    ws.conditional_formatting.add("G3:G500",
        CellIsRule(operator="equal", formula=['"LOSS"'],
                   fill=PatternFill("solid", fgColor="FFC7CE")))
    ws.conditional_formatting.add("G3:G500",
        CellIsRule(operator="equal", formula=['"Pending"'],
                   fill=PatternFill("solid", fgColor="DDDDDD")))

    autosize(ws, [12, 9, 22, 26, 11, 7, 11, 11, 28])

    # Summary row at the top: cumulative record
    ws["K2"] = "Summary"
    ws["K2"].font = HEADER_FONT
    ws["K2"].fill = HEADER_FILL
    ws["K3"] = "Total wins"
    ws["L3"] = '=COUNTIF(G:G,"WIN")'
    ws["K4"] = "Total losses"
    ws["L4"] = '=COUNTIF(G:G,"LOSS")'
    ws["K5"] = "Win %"
    ws["L5"] = '=IFERROR(L3/(L3+L4),"")'
    ws["L5"].number_format = "0.0%"
    ws["K6"] = "Lock (⭐⭐⭐) record"
    ws["L6"] = '=COUNTIFS(F:F,"***",G:G,"WIN")&"-"&COUNTIFS(F:F,"***",G:G,"LOSS")'
    ws.column_dimensions["K"].width = 24
    ws.column_dimensions["L"].width = 14


# ── Tab 8: $100K Scenario Budget ─────────────────────────────────────────
# A "what if we had 100x the budget" plan, for context. Real $1K plan is
# in MASTER_STRATEGY §10. This tab shows what scaling the same playbook
# would look like — useful when raising or pitching for marketing spend.
# Three columns: current $1K plan, $25K scenario (early traction), $100K
# scenario (post-seed marketing push). All figures are realistic
# market-rate estimates for the 18-day window.
def build_scenario_budget(wb):
    ws = wb.create_sheet("8 · $100K Scenario")
    ws.sheet_view.showGridLines = False

    # Section banner
    ws.merge_cells("A1:F1")
    ws["A1"] = "MARKETING BUDGET SCENARIOS — $1K (now) / $25K / $100K"
    ws["A1"].font = SECTION_FONT; ws["A1"].fill = SECTION_FILL; ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 32

    # Intro context block
    ws.merge_cells("A2:F2")
    ws["A2"] = ("This tab models what the same 18-day playbook would deliver at 25× and 100× the current $1,000 budget. "
                "All numbers are realistic 2026 market rates. Use this when pitching seed/series-A on what marketing dollars buy.")
    ws["A2"].font = SUBTLE_FONT
    ws["A2"].alignment = WRAP
    ws.row_dimensions[2].height = 36

    # Headers
    headers = ["Line item", "What it gets you", "$1K (current)", "$25K (early traction)", "$100K (post-seed)", "Notes"]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=4, column=c, value=h)
    style_header_row(ws, 4, len(headers))
    ws.freeze_panes = "A5"

    rows = [
        # PAID ACQUISITION
        ("[Paid Acquisition]", "", "", "", "", ""),
        ("Meta Ads — cold", "Lookalikes + interest stacks", 400, 6000, 15000,
         "$1.50 CPL target. $400 = 250 signups; $6K = 4K signups; $15K = 10K signups."),
        ("Meta Ads — retargeting", "Pixel-visited but didn't sign up", 150, 2500, 5000,
         "Always higher CTR than cold. 3-7x lower CPL. Burns hot."),
        ("TikTok Spark Ads", "Boost organic Reels that pop", 150, 3000, 10000,
         "Only deploy on Reels that already crossed 50K views organically. Otherwise it's lighting money on fire."),
        # ── Subtotal row
        ("  → Subtotal: paid digital", "", "=SUM(C6:C8)", "=SUM(D6:D8)", "=SUM(E6:E8)", ""),

        # INFLUENCER
        ("[Influencer]", "", "", "", "", ""),
        ("Macro creator (1, 1M+ followers)", "Sports/betting niche, 1 sponsored post or video w/ exclusive code", 0, 0, 20000,
         "$15-25K market rate for a single post from a 1M+ sports creator. Single biggest line item at $100K — but the lift is exponential."),
        ("Mid-tier creators (4-6, 200-500K)", "Sponsored IG/TikTok posts, mix paid + product-trade", 0, 5000, 15000,
         "$2-3K avg per post for 200-500K followers. Best CAC/LTV mix."),
        ("Micro creators (15-20, 50-150K)", "Paid + product-trade mix; ref-code attribution", 0, 2000, 10000,
         "$500-1K per post. Highest engagement rate; 20 small bets beat 1 big one."),
        ("Influencer trades (free Pro)", "$0 cost — Lifetime Pro for honest review (10-20 micros)", 0, 0, 0,
         "Always-on. $0 line item but real value. 20-creator DM list already in tab 6."),
        ("  → Subtotal: influencer", "", "=SUM(C11:C14)", "=SUM(D11:D14)", "=SUM(E11:E14)", ""),

        # PRODUCTION / CONTENT
        ("[Content Production]", "", "", "", "", ""),
        ("Live 'man on the street' TikTok shoots", "Multi-city sports-fan reactions to AI picks", 0, 4000, 18000,
         "Pro creator + videographer + 4-8 city shoots ($1.5-2.5K each) + edits + music licensing. Closest thing to 'guaranteed viral' for sports."),
        ("Branded creative (Canva Pro Team, Pond5, motion design)", "Evergreen content library", 50, 1000, 3000,
         "$50 currently covers Canva Pro + Pond5 single licenses. $3K = pro motion designer for 4-6 hero animations."),
        ("Studio/voiceover for hero ad", "Single high-production-value hero ad", 0, 0, 5000,
         "Skip at $1K and $25K. At $100K it's worth it for the YouTube pre-roll + paid social hero asset."),
        ("  → Subtotal: production", "", "=SUM(C17:C19)", "=SUM(D17:D19)", "=SUM(E17:E19)", ""),

        # SWEEPS / VIRAL
        ("[Sweeps & Viral Mechanics]", "", "", "", "", ""),
        ("Sweepstakes prize budget", "Headline prize value", 500, 5000, 25000,
         "Currently: 2 WC tickets ($500). $25K scenario: upgrade to $5K cash. $100K scenario: $25K cash or 5 winners × $5K each — drives 10x more entries."),
        ("Gleam Hobby/Pro plan", "Unlocks Feature Media, Viral Share, Repeat Action", 0, 39, 200,
         "$39/mo Hobby unlocks Feature Media + Repeat Action. $200/mo Business unlocks Custom CSS + advanced anti-fraud. Currently blocked us tonight."),
        ("KingSumo / Woorise paid tier", "Higher entry caps + advanced anti-bot", 0, 0, 500,
         "$500 unlocks 10K+ entries cap, custom branding, removes 'Powered by' footer. Worth at scale."),
        ("SparkLoop newsletter cross-promo", "$1-2 / signup via Morning Brew, The Hustle, etc.", 0, 2000, 8000,
         "100-200 signups at $200 budget. Scale linearly. Higher LTV than Meta cold."),
        ("Daily Drop on Twitter (7×$25 prizes)", "Daily micro-sweeps the week before launch", 0, 175, 700,
         "$25/day × 7 days = $175 currently. At $100K bump to $100/day × 7 = $700."),
        ("  → Subtotal: sweeps & viral", "", "=SUM(C22:C26)", "=SUM(D22:D26)", "=SUM(E22:E26)", ""),

        # PR & EARNED MEDIA
        ("[PR & Earned Media]", "", "", "", "", ""),
        ("PR firm retainer (1 month, mid-tier)", "Targeted outreach to The Hustle, Morning Brew, sports media", 0, 0, 3000,
         "1 month with a small/mid-tier firm. Worth it if even one Hustle/MB pickup lands."),
        ("Press kit + media training", "Photography, founder bio, talking points", 0, 500, 1500,
         "Professional shots + crisp positioning for press intake."),
        ("ProductHunt coordinated launch", "Hunter, day-of comms, video, asset polish", 0, 0, 1500,
         "Free at $1K (DIY). $1.5K covers a paid hunter + animated demo for PH listing."),
        ("Hacker News Show HN", "Free — just need polish + timing", 0, 0, 0,
         "$0 line. Timing-sensitive (Tuesday 8am ET). Front page = 50K-200K visits."),
        ("  → Subtotal: PR & earned", "", "=SUM(C29:C32)", "=SUM(D29:D32)", "=SUM(E29:E32)", ""),

        # OTHER / TOOLING
        ("[Tooling & Infra]", "", "", "", "", ""),
        ("Resend / Supabase / Vercel / etc.", "Email + DB + hosting", 0, 100, 500,
         "Free tier suffices at $1K-25K. $500/mo plans needed at scale (Resend Pro, Supabase Pro, Vercel Pro)."),
        ("Analytics / attribution stack", "PostHog, Plausible, GA4 setup", 0, 100, 1000,
         "DIY at $1K (free tiers). $1K covers a 1-time analytics consultant to build proper funnels."),
        ("Founder time (Noa) — opportunity cost", "Not a line item, but real", 0, 0, 0,
         "Excluded from this budget. Worth noting."),
        ("  → Subtotal: tooling", "", "=SUM(C35:C37)", "=SUM(D35:D37)", "=SUM(E35:E37)", ""),

        # CONTINGENCY
        ("[Contingency]", "", "", "", "", ""),
        ("Reallocation reserve", "Day 10 reallocate to top-performing channel", 250, 1500, 5000,
         "Critical. Whichever channel is winning by Day 10, dump 30% of the budget into it."),

        # ── TOTAL
        ("", "", "", "", "", ""),
        ("TOTAL", "", "=C6+C7+C8+C11+C12+C13+C14+C17+C18+C19+C22+C23+C24+C25+C26+C29+C30+C31+C32+C35+C36+C37+C41",
                     "=D6+D7+D8+D11+D12+D13+D14+D17+D18+D19+D22+D23+D24+D25+D26+D29+D30+D31+D32+D35+D36+D37+D41",
                     "=E6+E7+E8+E11+E12+E13+E14+E17+E18+E19+E22+E23+E24+E25+E26+E29+E30+E31+E32+E35+E36+E37+E41",
                     "Excluding $0 in-kind items + founder time"),
    ]

    # Find total row index
    for r, row in enumerate(rows, start=5):
        for c, v in enumerate(row, start=1):
            cell = ws.cell(row=r, column=c, value=v)
            cell.alignment = WRAP if c in (2, 6) else (CENTER if c >= 3 and c <= 5 else LEFT)
            # Section banners (rows where col B is empty and col A starts with [)
            if str(row[0]).startswith("[") and str(row[1]) == "":
                cell.font = Font(name="Calibri", bold=True, size=11, color=BRAND_BG)
                cell.fill = PatternFill("solid", fgColor="F4F4F4")
            # Subtotal rows
            elif str(row[0]).strip().startswith("→"):
                cell.font = Font(name="Calibri", bold=True, size=10, color="333333")
                cell.fill = PatternFill("solid", fgColor="EFEFEF")
            # TOTAL row
            elif row[0] == "TOTAL":
                cell.font = Font(name="Calibri", bold=True, size=12, color=BRAND_BG)
                cell.fill = HEADER_FILL
            # Number cols
            if c in (3, 4, 5) and isinstance(v, (int, float)):
                cell.number_format = "$#,##0"
            elif c in (3, 4, 5) and isinstance(v, str) and v.startswith("="):
                cell.number_format = "$#,##0"
        ws.row_dimensions[r + 0].height = 30

    autosize(ws, [40, 50, 14, 18, 18, 60])

    # ── Expected outcomes section ──
    out_row = len(rows) + 7  # leave a gap

    ws.merge_cells(f"A{out_row}:F{out_row}")
    ws.cell(row=out_row, column=1, value="EXPECTED OUTCOMES (18-day pre-launch sprint)")
    ws.cell(row=out_row, column=1).font = SECTION_FONT
    ws.cell(row=out_row, column=1).fill = SECTION_FILL
    ws.cell(row=out_row, column=1).alignment = CENTER
    ws.row_dimensions[out_row].height = 32

    outcome_headers = ["Metric", "Target", "$1K plan", "$25K plan", "$100K plan", "Notes"]
    for c, h in enumerate(outcome_headers, start=1):
        ws.cell(row=out_row + 1, column=c, value=h)
    style_header_row(ws, out_row + 1, len(outcome_headers))

    outcomes = [
        ("Waitlist signups (May 31)", "1,500", "1,500-2,500", "8,000-15,000", "25,000-50,000",
         "Linear scaling on Meta + influencer; sub-linear on organic (organic has reach ceiling)."),
        ("Cost per waitlist signup (blended)", "<$1.50", "$0.40-$0.67", "$1.67-$3.13", "$2.00-$4.00",
         "Goes UP with scale (you can't fake-organic at scale). Still cheap vs SaaS norms ($25-100 CAC)."),
        ("Instagram followers gained", "—", "500-1.5K", "5K-15K", "20K-50K",
         "Influencer + paid TikTok cross-pollinate IG."),
        ("TikTok followers gained", "—", "1K-3K", "8K-20K", "30K-75K",
         "TikTok rewards consistency + paid Spark Ads. Biggest multiplier at $100K."),
        ("Twitter followers gained", "—", "200-500", "2K-5K", "8K-20K",
         "Twitter is hardest to grow organically. PR + Show HN moves the needle here."),
        ("Press placements", "1-2", "1 small", "3-5 mid", "5-10 incl. 1-2 tier-1",
         "$1K = founder hustle. $25K = niche placements (Sports Illustrated digital, Bleacher Report). $100K = potential TechCrunch / The Hustle."),
        ("Viral pieces (>100K views, organic)", "1", "0-1", "2-4", "4-8",
         "Need quality + volume. Live street TikToks at $100K specifically engineered for this."),
        ("Brand recall in target audience (post-launch survey)", "—", "<5%", "10-20%", "25-40%",
         "Estimated via post-launch user survey. At $100K + a press hit, brand becomes a known name in the bettor demo."),
        ("Lifetime Pro conversions (% of signups)", "1-2%", "15-30 ($45-450 ARR)", "80-300 ($240-9K ARR)", "250-1.5K ($750-45K ARR)",
         "Conservative. Lifetime Pro at $30 launch promo, $150 regular. Actual conversion depends on launch-week comms."),
    ]
    for r, row in enumerate(outcomes, start=out_row + 2):
        for c, v in enumerate(row, start=1):
            cell = ws.cell(row=r, column=c, value=v)
            cell.alignment = WRAP if c in (2, 3, 4, 5, 6) else LEFT
            cell.font = BODY_FONT
        ws.row_dimensions[r].height = 36

    # ── Strategy notes section ──
    notes_row = out_row + 2 + len(outcomes) + 2

    ws.merge_cells(f"A{notes_row}:F{notes_row}")
    ws.cell(row=notes_row, column=1, value="STRATEGY NOTES — what changes at each scale")
    ws.cell(row=notes_row, column=1).font = SECTION_FONT
    ws.cell(row=notes_row, column=1).fill = SECTION_FILL
    ws.cell(row=notes_row, column=1).alignment = CENTER
    ws.row_dimensions[notes_row].height = 32

    notes = [
        ("$1K (current):",
         "Founder-led hustle. Every dollar of ad spend is rationed. Distribution is paste-and-post + organic + sweeps. Goal is to PROVE the funnel works before raising. Target CPL <$1.50, founder time covers everything else."),
        ("$25K (early traction):",
         "First serious paid push. Hire 1-3 micro creators for paid posts. Upgrade Gleam to Hobby to unlock branded image + viral share. Add a small PR push (DIY founder outreach with media training). 5-10x the signup count of $1K plan."),
        ("$100K (post-seed marketing):",
         "Real campaign. Macro influencer ($15-25K single post), multi-city 'man on the street' TikTok shoots ($18K), bigger sweeps prize ($25K cash gets 10x more entrants than $500 tickets), PR firm retainer, ProductHunt-coordinated launch with paid hunter. Brand starts to feel like a 'thing' in the sports-bettor demo."),
        ("Diminishing returns above $100K:",
         "Once you're at 50K+ pre-launch waitlist, the bottleneck becomes product, not marketing. Spending more on awareness without conversion infrastructure (onboarding, retention loop, paid tier) is wasted. Set the marketing pause at signup target."),
    ]
    for r, (label, txt) in enumerate(notes, start=notes_row + 1):
        ws.cell(row=r, column=1, value=label)
        ws.cell(row=r, column=1).font = Font(name="Calibri", bold=True, size=11, color=BRAND_BG)
        ws.merge_cells(f"B{r}:F{r}")
        ws.cell(row=r, column=2, value=txt)
        ws.cell(row=r, column=2).font = BODY_FONT
        ws.cell(row=r, column=2).alignment = WRAP
        ws.row_dimensions[r].height = 52


# ── README tab (first one) ───────────────────────────────────────────────
def build_readme(wb):
    ws = wb.create_sheet("0 · README", 0)  # insert first
    ws.sheet_view.showGridLines = False
    ws.merge_cells("A1:F1")
    ws["A1"] = "PICK1 · MASTER TRACKER"
    ws["A1"].font = Font(name="Calibri", bold=True, size=22, color=WHITE)
    ws["A1"].fill = SECTION_FILL
    ws["A1"].alignment = CENTER
    ws.row_dimensions[1].height = 44

    lines = [
        ("How to use this", "header"),
        ("This sheet is the EXECUTION log. The strategy doc (launch/MASTER_STRATEGY.md) is the plan; this is the daily-update tracker.", "body"),
        ("", "body"),
        ("Update cadence: every night before bed. Takes ~3 min.", "body"),
        ("Sundays: full audit + reallocation decisions for the week ahead.", "body"),
        ("", "body"),
        ("The 8 tabs", "header"),
        ("1. KPI Dashboard         — top-level daily numbers (signups, CPL, etc.)", "body"),
        ("2. Content Calendar      — every post planned + posted, with perf", "body"),
        ("3. Ad Performance        — Meta + TikTok Spark per-day per-ad", "body"),
        ("4. Channel ROI           — which channel is winning, % of total (29 channels tracked)", "body"),
        ("5. Activations           — the 11 viral activations + state", "body"),
        ("6. Influencer Outreach   — the 20-DM micro-trade program", "body"),
        ("7. Pick Performance      — daily pick record (the receipts wall)", "body"),
        ("8. $100K Scenario        — what marketing spend would look like at $1K vs $25K vs $100K", "body"),
        ("", "body"),
        ("North Star", "header"),
        ("1,500 waitlist signups by May 31. Stretch target: 2,500.", "body"),
        ("Budget: $1,000 total. CPL target: < $1.50.", "body"),
        ("", "body"),
        ("Quick references", "header"),
        ("Strategy doc:   launch/MASTER_STRATEGY.md", "body"),
        ("Site:           https://pick1.live", "body"),
        ("FB Page:        https://www.facebook.com/profile.php?id=61589631453496", "body"),
        ("Resend domain:  pick1.live (verified)", "body"),
        ("Supabase proj:  lgnjawngkiamlngcffrk (eu-central-2)", "body"),
    ]
    for i, (text, style) in enumerate(lines, start=3):
        ws.cell(row=i, column=1, value=text)
        if style == "header":
            ws.cell(row=i, column=1).font = Font(name="Calibri", bold=True, size=14, color=BRAND_BG)
            ws.row_dimensions[i].height = 22
        else:
            ws.cell(row=i, column=1).font = Font(name="Calibri", size=11)
    ws.column_dimensions["A"].width = 110


def main():
    wb = Workbook()
    # Remove the default sheet so we control insertion order
    default = wb.active
    wb.remove(default)

    build_kpi_dashboard(wb)
    build_content_calendar(wb)
    build_ad_performance(wb)
    build_channel_roi(wb)
    build_activations(wb)
    build_influencer_outreach(wb)
    build_pick_performance(wb)
    build_scenario_budget(wb)
    build_readme(wb)  # inserted at position 0

    out = Path(__file__).parent / "MASTER_TRACKER.xlsx"
    wb.save(out)
    print(f"✓ Wrote {out}  ({len(wb.sheetnames)} tabs)")


if __name__ == "__main__":
    main()
