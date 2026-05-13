#!/usr/bin/env python3
"""
Pick1 — Master Tracker generator.

Produces `MASTER_TRACKER.xlsx` next to this script. Seven tabs covering
everything we measure during the 18-day pre-launch sprint:

  1. KPI Dashboard       — top-level numbers, day-by-day
  2. Content Calendar    — what's getting posted where + perf
  3. Ad Performance      — Meta + TikTok Spark spend / CPL / conversions
  4. Channel ROI         — which channel is winning, % of total
  5. Activation Pipeline — the 5 viral activations + their state
  6. Influencer Outreach — 20-DM micro-influencer trade program
  7. Pick Performance    — daily pick record (the receipts wall data)

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

    channels = ["Meta Ads", "TikTok organic", "TikTok Spark (paid boost)",
                "X / Twitter organic", "Instagram organic", "Reddit",
                "Influencer trades", "ProductHunt", "Founder essay",
                "Email referrals (own list)", "Gleam sweepstakes",
                "SparkLoop newsletter cross-promo", "Telegram channel",
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
        (1, "Position-jumping referral", "Day 1 (live)", "LIVE",
         "Claude",
         "Every signup gets pick1.live/?r=<code>. +100 positions per ref. 3 / 10 / 25 reward tiers."),
        (2, "Public Accountability Bet", "Day 8 (May 20)", "Planned",
         "Noa",
         "'If locks lose at < 60% over 30 days, first paid month refunded.' Needs public dashboard."),
        (3, "Beat the AI challenge", "Day 18 (May 30)", "Planned",
         "Claude (build) + Noa (launch)",
         "Twitter hashtag #BeatPick1. Weekly leaderboard. Winner gets year of Pro."),
        (4, "Influencer trade program", "Day 4 (May 16)", "Planned",
         "Noa (DMs) + Claude (list)",
         "DM 20 micro-influencers (5K-50K). Free year of Pro + custom ref code for honest 7-day review."),
        (5, "Founder story drop", "Day 14-15 (May 26-27)", "Planned",
         "Noa (record) + Claude (cross-post)",
         "Coordinated multi-platform 'how I built this' content. Twitter thread + TikTok + IG + Substack."),
        (6, "Gleam 'World Cup Tickets' Sweepstakes", "Day 5 (May 17)", "Planned",
         "Claude (setup) + Noa (prize fulfillment)",
         "Prize: 2 group-stage 2026 FIFA WC tickets + Lifetime Pro (~$500). MANDATORY GATEWAY: waitlist signup required to win (zero entries otherwise). Bonus tasks layer IG +5, TikTok +5, Twitter +3, refer +10, daily +1. Runs May 17 → May 31. Embed on pick1.live."),
        (7, "SparkLoop Newsletter Cross-Promo", "Day 8 (May 20)", "Planned",
         "Claude (apply) + auto",
         "Pay $1-2/signup for Pick1 to appear in Morning Brew / The Hustle / sports newsletters' welcome emails. Budget cap: $200 for the 18-day window. Higher LTV than Meta cold."),
        (8, "Telegram Pre-Launch Channel", "Day 3 (May 15)", "Planned",
         "Claude (setup + webhook)",
         "Pick1 Daily Picks channel. Auto-posts via Supabase webhook at 9am ET. Member count embedded on pick1.live as social proof."),
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
        ("The 7 tabs", "header"),
        ("1. KPI Dashboard         — top-level daily numbers (signups, CPL, etc.)", "body"),
        ("2. Content Calendar      — every post planned + posted, with perf", "body"),
        ("3. Ad Performance        — Meta + TikTok Spark per-day per-ad", "body"),
        ("4. Channel ROI           — which channel is winning, % of total", "body"),
        ("5. Activations           — the 5 viral activations + state", "body"),
        ("6. Influencer Outreach   — the 20-DM micro-trade program", "body"),
        ("7. Pick Performance      — daily pick record (the receipts wall)", "body"),
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
    build_readme(wb)  # inserted at position 0

    out = Path(__file__).parent / "MASTER_TRACKER.xlsx"
    wb.save(out)
    print(f"✓ Wrote {out}  ({len(wb.sheetnames)} tabs)")


if __name__ == "__main__":
    main()
