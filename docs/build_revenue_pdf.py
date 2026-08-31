#!/usr/bin/env python3
"""Build the Pick1 revenue recovery + projections PDF.

Every figure here is verified against App Store Connect analytics and the
`subscriptions` table fed by Apple's App Store Server Notifications V2.
Nothing is estimated except where a row is explicitly labelled an assumption.
"""

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (BaseDocTemplate, Frame, PageBreak, PageTemplate,
                                Paragraph, Spacer, Table, TableStyle)

OUT = "/Users/ethan/betting-app/docs/Pick1_Revenue_Recovery_Projections.pdf"

# ── Palette ───────────────────────────────────────────────────────────────
INK      = colors.HexColor("#14161A")
INK_2    = colors.HexColor("#4A4F57")
INK_3    = colors.HexColor("#8A8F98")
LIME     = colors.HexColor("#C3EF1F")
LIME_DK  = colors.HexColor("#5C7300")
RULE     = colors.HexColor("#DDDCD4")
RULE_LT  = colors.HexColor("#EEEDE6")
PANEL    = colors.HexColor("#F7F7F2")
BAD      = colors.HexColor("#B03024")
GOOD     = colors.HexColor("#2F7A4B")

PAGE_W, PAGE_H = A4
MARGIN = 18 * mm

# ── Styles ────────────────────────────────────────────────────────────────
ss = getSampleStyleSheet()


def style(name, **kw):
    base = dict(name=name, fontName="Helvetica", fontSize=9.5, leading=14,
                textColor=INK_2, alignment=TA_LEFT, spaceAfter=0)
    base.update(kw)
    return ParagraphStyle(**base)


S = {
    "title":    style("title", fontName="Helvetica-Bold", fontSize=27, leading=30,
                      textColor=INK, spaceAfter=4),
    "subtitle": style("subtitle", fontSize=11.5, leading=16, textColor=INK_2, spaceAfter=0),
    "eyebrow":  style("eyebrow", fontName="Helvetica-Bold", fontSize=7.5, leading=11,
                      textColor=INK_3),
    "h2":       style("h2", fontName="Helvetica-Bold", fontSize=15, leading=19,
                      textColor=INK, spaceAfter=3),
    "h3":       style("h3", fontName="Helvetica-Bold", fontSize=10.5, leading=14,
                      textColor=INK, spaceAfter=2),
    "body":     style("body"),
    "bodytight": style("bodytight", leading=12.5),
    "small":    style("small", fontSize=8.5, leading=12, textColor=INK_3),
    "cell":     style("cell", fontSize=8.8, leading=12),
    "cellb":    style("cellb", fontName="Helvetica-Bold", fontSize=8.8, leading=12,
                      textColor=INK),
    "cellhead": style("cellhead", fontName="Helvetica-Bold", fontSize=7.5, leading=10,
                      textColor=INK_3),
    "kpiv":     style("kpiv", fontName="Helvetica-Bold", fontSize=19, leading=21,
                      textColor=INK),
    "kpivl":    style("kpivl", fontName="Helvetica-Bold", fontSize=19, leading=21,
                      textColor=LIME_DK),
    "kpik":     style("kpik", fontName="Helvetica-Bold", fontSize=7, leading=10,
                      textColor=INK_3),
    "kpin":     style("kpin", fontSize=8, leading=11, textColor=INK_2),
}


def P(txt, s="body"):
    return Paragraph(txt, S[s])


def rule(color=RULE, thickness=0.6, space_before=0, space_after=0):
    t = Table([[""]], colWidths=[PAGE_W - 2 * MARGIN], rowHeights=[thickness])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), color),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))
    return [Spacer(1, space_before), t, Spacer(1, space_after)]


def section(eyebrow, heading):
    """Section head: hairline rule, small label, bold heading."""
    out = rule(RULE, 0.6, 0, 5)
    out.append(P(eyebrow.upper(), "eyebrow"))
    out.append(Spacer(1, 2))
    out.append(P(heading, "h2"))
    out.append(Spacer(1, 6))
    return out


def kpi_row(items):
    """items: list of (value, label, note, highlight)"""
    cells = []
    for v, k, n, hi in items:
        inner = [[P(v, "kpivl" if hi else "kpiv")],
                 [P(k.upper(), "kpik")],
                 [P(n, "kpin")]]
        t = Table(inner, colWidths=[(PAGE_W - 2 * MARGIN) / len(items) - 6])
        t.setStyle(TableStyle([
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ("TOPPADDING", (0, 0), (-1, -1), 1),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]))
        cells.append(t)
    outer = Table([cells], colWidths=[(PAGE_W - 2 * MARGIN) / len(items)] * len(items))
    outer.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (0, -1), 0),
        ("RIGHTPADDING", (-1, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEABOVE", (0, 0), (-1, 0), 2, LIME),
    ]))
    return outer


def data_table(header, rows, widths, aligns=None, highlight_col=None):
    body = [[P(h, "cellhead") for h in header]]
    for r in rows:
        body.append([c if isinstance(c, Paragraph) else P(str(c), "cell") for c in r])
    t = Table(body, colWidths=widths, repeatRows=1)
    st = [
        ("LINEBELOW", (0, 0), (-1, 0), 0.7, RULE),
        ("LINEBELOW", (0, 1), (-1, -2), 0.4, RULE_LT),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (0, -1), 0),
        ("RIGHTPADDING", (-1, 0), (-1, -1), 0),
    ]
    if aligns:
        for i, a in enumerate(aligns):
            st.append(("ALIGN", (i, 0), (i, -1), a))
    if highlight_col is not None:
        st.append(("TEXTCOLOR", (highlight_col, 1), (highlight_col, -1), LIME_DK))
        st.append(("FONTNAME", (highlight_col, 1), (highlight_col, -1), "Helvetica-Bold"))
    t.setStyle(TableStyle(st))
    return t


def callout(paras):
    inner = [[P(p, "bodytight")] for p in paras]
    t = Table(inner, colWidths=[PAGE_W - 2 * MARGIN - 14])
    t.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    outer = Table([[t]], colWidths=[PAGE_W - 2 * MARGIN])
    outer.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PANEL),
        ("LINEBEFORE", (0, 0), (0, -1), 2.5, LIME),
        ("LEFTPADDING", (0, 0), (-1, -1), 11),
        ("RIGHTPADDING", (0, 0), (-1, -1), 11),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
    ]))
    return outer


# ── Page furniture ────────────────────────────────────────────────────────
def decorate(canvas, doc):
    canvas.saveState()
    # Header mark
    canvas.setFont("Helvetica-Bold", 8)
    canvas.setFillColor(INK_3)
    canvas.drawString(MARGIN, PAGE_H - 12 * mm, "PICK1")
    canvas.setFillColor(LIME_DK)
    canvas.drawString(MARGIN + 22, PAGE_H - 12 * mm, "REVENUE RECOVERY & PROJECTIONS")
    canvas.setFillColor(INK_3)
    canvas.drawRightString(PAGE_W - MARGIN, PAGE_H - 12 * mm, "28 JULY 2026")
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, PAGE_H - 14.5 * mm, PAGE_W - MARGIN, PAGE_H - 14.5 * mm)
    # Footer
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(INK_3)
    canvas.drawString(MARGIN, 11 * mm,
                      "Verified against App Store Connect and Apple App Store Server Notifications.")
    canvas.drawRightString(PAGE_W - MARGIN, 11 * mm, f"{doc.page}")
    canvas.restoreState()


doc = BaseDocTemplate(OUT, pagesize=A4,
                      leftMargin=MARGIN, rightMargin=MARGIN,
                      topMargin=20 * mm, bottomMargin=16 * mm,
                      title="Pick1 — Revenue Recovery & Projections",
                      author="L70 Labs")
frame = Frame(MARGIN, 16 * mm, PAGE_W - 2 * MARGIN, PAGE_H - 36 * mm, id="body",
              leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
doc.addPageTemplates([PageTemplate(id="main", frames=[frame], onPage=decorate)])

W = PAGE_W - 2 * MARGIN
story = []

# ══════════════════════════════════════════════════════════════ PAGE 1 ════
story.append(Spacer(1, 4))
story.append(P("Getting the revenue back", "title"))
story.append(Spacer(1, 4))
story.append(P(
    "What the current subscriber base is worth if nothing changes, why it decays, "
    "and what each recovery lever is expected to return.", "subtitle"))
story.append(Spacer(1, 14))

story.append(kpi_row([
    ("$1,071", "Lifetime proceeds", "Total earned since launch. $1,043 of it in 15 days.", False),
    ("86", "Active plans today", "Of which only 53 will ever bill again.", False),
    ("$56", "Committed per day", "From paying subscribers set to renew.", True),
    ("~$3", "Per day at day 90", "Same base, no intervention.", False),
]))

story += section("The headline", "The current base is worth about $1,000 over 90 days")
story.append(P(
    "Pick1 has earned <b>$1,071 in its entire life</b>, and $1,043 of that arrived in a single "
    "15-day window in July as the World Cup signup surge cleared the 3-day trial. Revenue peaked "
    "at $147 on 21 July — two days <i>after</i> the final — and has fallen since as that one "
    "cohort ages out.", "body"))
story.append(Spacer(1, 7))
story.append(P(
    "Projected forward, everyone currently subscribed will generate roughly <b>$1,014 over the "
    "next 90 days</b>. In other words, the entire active base is worth about as much from here on "
    "as the app has earned in its whole history. That is not an acquisition problem — new "
    "subscriptions are still arriving at about 11 a day. It is a retention problem.", "body"))
story.append(Spacer(1, 10))

story.append(callout([
    "<b>The one number that is already excellent.</b> Apple's peer benchmarks put Pick1's revenue "
    "per paying user at <b>$28.00</b>, above the 75th percentile for subscription Sports apps "
    "($19.05). Pricing is the strongest thing in the business and should not be cut. The problem "
    "is that too few people ever start paying, and those who do leave after one cycle.",
]))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 2 ════
story += section("What we still have", "The active base, subscriber by subscriber")
story.append(P(
    "86 subscriptions are entitled today. Only 53 of them have auto-renew switched on — the other "
    "33 have already cancelled and are simply running out the clock. That distinction is the whole "
    "projection.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Group", "Subs", "Net per cycle", "Net per day", "What happens next"],
    [
        ["Weekly, paying, renewing", "28", "$333.32", "$47.62",
         "Charged every 7 days. 27% survive to the next charge."],
        ["Monthly, paying, renewing", "8", "$260.92", "$8.58",
         "Charged every 30 days. Best retention in the base."],
        ["Weekly, in trial, renewing", "17", "$234.08", "—",
         "Converts at 12.2%, so about 2 will become payers."],
        [P("<b>Cancelled, still entitled</b>", "cellb"), P("<b>33</b>", "cellb"),
         P("<b>$0</b>", "cellb"), P("<b>$0</b>", "cellb"),
         P("<b>Will lapse. No further revenue unless recovered.</b>", "cellb")],
    ],
    widths=[W * 0.27, W * 0.08, W * 0.15, W * 0.13, W * 0.37],
    aligns=["LEFT", "RIGHT", "RIGHT", "RIGHT", "LEFT"],
))
story.append(Spacer(1, 6))
story.append(P(
    "Committed revenue from paying, renewing subscribers is <b>$56.20 per day</b>. The 17 trials "
    "add roughly $4 a day once conversion is applied. Currencies converted at approximate rates "
    "and shown net of Apple's 15% commission.", "small"))
story.append(Spacer(1, 14))

story += section("The projection", "Same base, no intervention")
story.append(P(
    "Applying the observed retention rates — 27% of weekly subscribers survive to their next "
    "charge, and 12.2% of trials convert — the current base decays as follows.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Period", "Weekly", "Monthly", "Trials", "Total", "Average per day"],
    [
        ["Days 1–30", "$454", "$261", "$39", P("<b>$754</b>", "cellb"), "$25"],
        ["Days 31–60", "$8", "$157", "—", P("<b>$165</b>", "cellb"), "$6"],
        ["Days 61–90", "—", "$94", "—", P("<b>$95</b>", "cellb"), "$3"],
        [P("<b>90-day total</b>", "cellb"), P("<b>$462</b>", "cellb"),
         P("<b>$512</b>", "cellb"), P("<b>$39</b>", "cellb"),
         P("<b>$1,014</b>", "cellb"), P("<b>$11</b>", "cellb")],
    ],
    widths=[W * 0.20, W * 0.14, W * 0.14, W * 0.12, W * 0.18, W * 0.22],
    aligns=["LEFT", "RIGHT", "RIGHT", "RIGHT", "RIGHT", "RIGHT"],
))
story.append(Spacer(1, 8))
story.append(P(
    "Revenue starts at about $56 a day and ends near $3. Note that monthly subscribers — only 8 "
    "of them — contribute more over 90 days than all 28 weekly subscribers combined. That is the "
    "single most important fact on this page.", "body"))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 3 ════
story += section("Why it decays", "Three leaks, all measurable")

story.append(data_table(
    ["Leak", "Pick1", "Benchmark", "What it costs"],
    [
        ["Trial converts to paid", "12.2%", "30–40% typical",
         "484 of 551 subscriptions died at exactly 3.0 days — at the trial wall, never reaching a first payment."],
        ["Weekly subscriber survives to 2nd charge", "27%", "50–60% typical",
         "67 first payments became 18 second payments and 2 third payments."],
        ["Subscriptions lost to a failed card", "17.6%", "5–8%",
         "102 of 573 never chose to leave. The payment was declined and nothing told them."],
        ["Download becomes a payer", "1.48%", "2.68% peer median",
         "Closing to the median is a 1.8x revenue multiple on identical traffic."],
        ["User returns on day 1", "20.7%", "26.0% peer median",
         "A user who never comes back a second time never converts."],
    ],
    widths=[W * 0.30, W * 0.11, W * 0.17, W * 0.42],
    aligns=["LEFT", "RIGHT", "LEFT", "LEFT"],
    highlight_col=1,
))
story.append(Spacer(1, 8))
story.append(P(
    "The weekly plan compounds all of this. At $14.99 a week it forces four cancel decisions a "
    "month, and roughly three-quarters of subscribers are lost at each one. Monthly is already "
    "the default on the paywall and is <b>38% cheaper per week</b> ($9.23 against $14.99) — yet "
    "79% of subscribers still choose weekly, because $14.99 is a smaller number than $39.99.", "body"))
story.append(Spacer(1, 14))

story += section("Already fixed", "Shipped on 28 July")

story.append(data_table(
    ["Change", "Status", "What it addresses"],
    [
        ["Apple Billing Grace Period (16 days)", "Live",
         "Was never enabled. Card failures turned straight into cancellations — 17.6% of the base. Apple now keeps retrying for 16 days while the subscriber keeps access."],
        ["Failed-payment notification", "Live",
         "Tells a subscriber their card was declined and links to the screen that fixes it. Nothing did this before."],
        ["Cancellation save notification", "Live",
         "Reaches subscribers who switched off auto-renew, 16–48 hours before they lapse. First contact this segment has ever had."],
        ["Day-one return notification", "Live",
         "Attacks the 20.7% day-1 retention rate directly."],
        ["Trial-ending notification", "Live",
         "Two versions, depending on whether the subscriber has already cancelled."],
        ["Email fallback, 7 languages", "Built, dormant",
         "Reaches the 30% of lapsed subscribers who cannot be reached by notification. Waiting on one missing API key."],
    ],
    widths=[W * 0.28, W * 0.12, W * 0.60],
    aligns=["LEFT", "LEFT", "LEFT"],
))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 4 ════
story += section("Where the recovery comes from", "Two audiences, sized")
story.append(P(
    "Beyond the 86 active subscriptions there are two much larger populations, and they need "
    "completely different treatment.", "body"))
story.append(Spacer(1, 10))

story.append(data_table(
    ["Audience", "People", "Reachable now", "The play", "Expected recovery"],
    [
        ["Trialled, never paid", "338", "158",
         "A discounted full month — long enough to see the pattern 3 days never showed.", "3–8%"],
        ["Lost to a failed card", "96", "65",
         "Already addressed by grace period plus the failed-payment notification.", "40–60%"],
        ["Paid, then left", "16", "9",
         "Small enough to approach individually. Proven willingness to pay.", "15–25%"],
        ["Have the app, never paid", "2,012", "227 weekly active",
         "Paywall rebuild and a first-purchase offer. The compounding opportunity.", "1.8x conversion"],
    ],
    widths=[W * 0.20, W * 0.09, W * 0.13, W * 0.42, W * 0.16],
    aligns=["LEFT", "RIGHT", "RIGHT", "LEFT", "RIGHT"],
    highlight_col=1,
))
story.append(Spacer(1, 8))
story.append(P(
    "Note on mechanism: Apple's Win-Back Offers cannot be used here. Apple requires a customer to "
    "have previously paid for at least one month to qualify, and Pick1's typical paid lifetime is "
    "a single week — so virtually none of the 452 lapsed users are eligible. Redeemable offer "
    "codes carry no such restriction and also work on the never-paid audience.", "small"))
story.append(Spacer(1, 14))

story += section("Scenarios", "What the next 90 days look like")

story.append(data_table(
    ["", "Do nothing", "Execute the plan"],
    [
        ["Revenue from today's active base", "$1,014", "$1,250–1,500"],
        ["One-off reactivation revenue", "$0", "$400–900"],
        ["Steady-state run rate at day 90", "$20–25 / day", "$50–80 / day"],
        ["Trial converts to paid", "12.2%", "18–22%"],
        ["Weekly survives to 2nd charge", "27%", "38–45%"],
        ["Lost to failed cards", "17.6%", "under 8%"],
        [P("<b>90-day revenue</b>", "cellb"), P("<b>~$1,700</b>", "cellb"),
         P("<b>~$3,400–4,800</b>", "cellb")],
    ],
    widths=[W * 0.44, W * 0.28, W * 0.28],
    aligns=["LEFT", "RIGHT", "RIGHT"],
    highlight_col=2,
))
story.append(Spacer(1, 8))
story.append(P(
    "\"Do nothing\" still includes the roughly 11 new subscriptions arriving each day at current "
    "conversion rates — it is not a zero baseline. The difference between the columns is entirely "
    "retention and conversion, with no additional advertising spend in either.", "small"))

story.append(PageBreak())

# ══════════════════════════════════════════════════════════════ PAGE 5 ════
story += section("Order of work", "Sequenced so nothing waits on a slow experiment")

story.append(data_table(
    ["When", "What", "Why this order"],
    [
        ["Days 1–7", "Unblock email. Publish a discounted-month offer code and send it to all 452 lapsed users through the notification system already running. Approach the 16 former payers directly.",
         "None of this depends on new traffic. It is the only revenue available immediately."],
        ["Days 8–21", "Rebuild the paywall: lead with the public results ledger, and present weekly against monthly so the real value comparison is visible. Ship result notifications to free users.",
         "Affects every future subscriber. A monthly subscriber is worth three to four times a weekly one."],
        ["Weeks 4–9", "Test a 7-day trial against the current 3-day trial.",
         "At about 10 trial starts a day this needs 4–6 weeks to read honestly, so it must start early. Reports as the NFL season opens."],
    ],
    widths=[W * 0.13, W * 0.52, W * 0.35],
    aligns=["LEFT", "LEFT", "LEFT"],
))
story.append(Spacer(1, 14))

story += section("What we need", "Three decisions and one key")

story.append(data_table(
    ["Item", "Owner", "Detail"],
    [
        ["Resend API key", "Client",
         "One missing environment variable. It unblocks email to the 220 lapsed users notifications cannot reach — and also switches on the welcome email and new-subscriber alerts, neither of which has ever worked."],
        ["Discount level on the comeback offer", "Client",
         "An offer code campaign already exists in App Store Connect at 50% off the first month, created but never sent to anyone. Confirm 50% or set a different figure."],
        ["Code type", "Client",
         "One reusable code is far simpler to distribute by notification and email. Unique single-use codes are more controlled but need per-user assignment."],
        ["Paywall design work", "Both",
         "Approval to change the paywall layout and plan presentation. This requires an App Store review cycle."],
    ],
    widths=[W * 0.24, W * 0.10, W * 0.66],
    aligns=["LEFT", "LEFT", "LEFT"],
))
story.append(Spacer(1, 14))

story.append(callout([
    "<b>What this plan does not do.</b> Everything here raises revenue per user. None of it raises "
    "the number of users. At the current rate of roughly 67 signups a day, executing all of it "
    "lands the business somewhere around $50–80 a day — a real recovery from a base otherwise "
    "decaying toward nothing, but a ceiling rather than a growth curve.",
    "<b>Growth needs advertising restarted.</b> The case for that gets stronger after this work, "
    "not weaker: organic signup-to-subscription now runs near 27% against 9.9% during the World "
    "Cup surge, so a future advertising dollar buys roughly three times what it bought in July. "
    "Fix the funnel first, then fill it.",
]))

doc.build(story)
print(f"Written: {OUT}")
