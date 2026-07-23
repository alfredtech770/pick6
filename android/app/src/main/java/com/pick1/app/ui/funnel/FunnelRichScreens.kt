package com.pick1.app.ui.funnel

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.components.FnlHeadline
import com.pick1.app.ui.theme.*

/**
 * The funnel screens that carry real layout beyond kicker/headline/lead —
 * ports of the iOS `GreenScreen` previews, `SocialProofScreen` and
 * `CompareScreen`.
 */

// ── Green "the fix" screens, with the in-app preview mockups ─────────

private data class GreenData(val kick: Int, val head: Int, val lead: Int, val cta: Int)

private val greens = listOf(
    GreenData(R.string.funnel_green1_kicker, R.string.funnel_green1_headline, R.string.funnel_green1_lead, R.string.funnel_green1_cta),
    GreenData(R.string.funnel_green2_kicker, R.string.funnel_green2_headline, R.string.funnel_green2_lead, R.string.funnel_green2_cta),
    GreenData(R.string.funnel_green3_kicker, R.string.funnel_green3_headline, R.string.funnel_green3_lead, R.string.funnel_green3_cta),
)

@Composable
fun GreenScreenRich(index: Int, onNext: () -> Unit) {
    val d = greens[index]
    FnlScreen(
        glow = Tone.WIN,
        bottom = { FnlCTA(stringResource(d.cta)) { onNext() } },
    ) {
        // 3-dot progress
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            repeat(3) { i ->
                Box(
                    Modifier
                        .width(22.dp).height(4.dp)
                        .clip(CircleShape)
                        .background(if (i <= index) P1.Win else P1.Line),
                )
            }
        }
        Spacer(Modifier.height(14.dp))
        FnlKick(stringResource(d.kick), tone = Tone.WIN)
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(d.head), accent = P1.Win, size = 40)
        Spacer(Modifier.height(14.dp))
        FnlLead(stringResource(d.lead))
        Spacer(Modifier.height(18.dp))

        // The design's "appframe" mockup. These depict real product features
        // (confidence ring, reasoning list, public ledger); the specific
        // matchups are illustrative, exactly as on iOS.
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(24.dp))
                .padding(18.dp),
        ) {
            when (index) {
                0 -> PickPreview()
                1 -> ReasoningPreview()
                else -> LedgerPreview()
            }
        }
    }
}

@Composable
private fun PreviewPill(text: String) {
    Text(
        text,
        style = archivoNarrow(9, FontWeight.Bold, tracking = 1.8f),
        color = P1.Ink,
        modifier = Modifier
            .clip(CircleShape)
            .background(P1.Win)
            .padding(horizontal = 9.dp, vertical = 4.dp),
    )
}

/** Fix 1 — today's top pick with the confidence ring. */
@Composable
private fun PickPreview() {
    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PreviewPill(stringResource(R.string.funnel_green_pill_pick))
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = P1.Foreground)) { append("CELTICS\n") }
                withStyle(SpanStyle(color = P1.LimeFunnel)) { append("OVER LAKERS") }
            },
            style = anton(22),
            textAlign = TextAlign.Center,
        )
        Text(
            "NBA · TONIGHT 7:30 PM ET",
            style = mono(10, FontWeight.Bold, tracking = 1.2f),
            color = P1.Mute,
        )
        Box(Modifier.padding(top = 4.dp).size(84.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val stroke = 8.dp.toPx()
                val inset = stroke / 2
                val s = Size(size.width - stroke, size.height - stroke)
                drawArc(
                    color = Color(0xFF22252B),
                    startAngle = 0f, sweepAngle = 360f, useCenter = false,
                    topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                    size = s,
                    style = Stroke(width = stroke),
                )
                drawArc(
                    color = Color(0xFFCDFA3F),
                    startAngle = -90f, sweepAngle = 360f * 0.81f, useCenter = false,
                    topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                    size = s,
                    style = Stroke(width = stroke, cap = StrokeCap.Round),
                )
            }
            Text("81%", style = anton(24), color = P1.LimeFunnel)
        }
        Text(
            stringResource(R.string.funnel_green_ai_conf),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 1.8f),
            color = P1.Mute,
        )
    }
}

/** Fix 2 — the "why" behind a pick. */
@Composable
private fun ReasoningPreview() {
    val reasons = listOf(
        "#2 vs #6 seed — SAS dominated",
        "Series opener · home rhythm edge",
        "11-2 ATS as a Game 1 favorite",
        "Pace gap +4.2 possessions",
    )
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        PreviewPill(stringResource(R.string.funnel_green_pill_why))
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = P1.Foreground)) { append("SPURS ML ") }
                withStyle(SpanStyle(color = P1.LimeFunnel)) { append("84.8% CONF") }
            },
            style = anton(19),
        )
        reasons.forEachIndexed { i, r ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Box(
                    Modifier.size(22.dp).clip(CircleShape).background(P1.LimeFunnel),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("${i + 1}", style = anton(13), color = P1.Ink)
                }
                Text(r, style = archivo(13, FontWeight.Medium), color = P1.Ink2, maxLines = 1)
            }
        }
    }
}

/** Fix 3 — the public ledger, losses included. */
@Composable
private fun LedgerPreview() {
    val rows = listOf(
        Triple("SPURS −5", "84.8%", true),
        Triple("KNICKS ML", "71.5%", true),
        Triple("RANGERS ML", "59.9%", false),
        Triple("CELTICS −7.5", "82.1%", true),
    )
    val every = stringResource(R.string.rd_ob_every)
    val result = stringResource(R.string.rd_ob_result)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PreviewPill(stringResource(R.string.funnel_green_pill_ledger))
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = P1.Foreground)) { append(every) }
                withStyle(SpanStyle(color = P1.LimeFunnel)) { append(result) }
            },
            style = anton(19),
        )
        rows.forEach { (name, pct, won) ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(name, style = archivo(13, FontWeight.Bold), color = P1.Foreground)
                Spacer(Modifier.weight(1f))
                Text(pct, style = mono(11, FontWeight.Bold), color = P1.Mute)
                Spacer(Modifier.width(8.dp))
                Text(
                    stringResource(if (won) R.string.funnel_green_won else R.string.funnel_green_loss),
                    style = archivoNarrow(10, FontWeight.Bold, tracking = 1.2f),
                    color = if (won) P1.Ink else P1.Foreground,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (won) P1.Win else P1.Hot.copy(alpha = 0.85f))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
        }
    }
}

// ── Social proof ─────────────────────────────────────────────────────

/**
 * REAL numbers from the picks ledger — every stat here is verifiable in the
 * app's own public win/loss log. Do NOT replace these with invented
 * testimonials or earnings claims: fabricated "$X won" figures are
 * false-advertising exposure in a betting-adjacent app and an App Review
 * "misleading content" risk. Refresh per release (same warning as iOS).
 */
@Composable
fun SocialProofScreen(onNext: () -> Unit) {
    val stats = listOf(
        Triple("🧾", "296", R.string.funnel_social1_title to R.string.funnel_social1_sub),
        Triple("🎯", "74%", R.string.funnel_social2_title to R.string.funnel_social2_sub),
        Triple("📊", "62%", R.string.funnel_social3_title to R.string.funnel_social3_sub),
    )
    FnlScreen(bottom = { FnlCTA(stringResource(R.string.funnel_social_cta)) { onNext() } }) {
        FnlKick(stringResource(R.string.funnel_social_kicker))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(R.string.funnel_social_headline), size = 40)
        Spacer(Modifier.height(20.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            stats.forEach { (emoji, big, labels) ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(P1.Panel)
                        .border(1.dp, P1.Line, RoundedCornerShape(18.dp))
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Box(
                        Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(13.dp))
                            .background(P1.LimeFunnel.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) { Text(emoji, style = archivo(22)) }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(stringResource(labels.first), style = archivo(14, FontWeight.Bold), color = P1.Foreground)
                        Text(stringResource(labels.second), style = archivo(12), color = P1.Mute)
                    }
                    Text(big, style = anton(26), color = P1.LimeFunnel)
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(R.string.funnel_social_disclaimer),
            style = archivo(11),
            color = P1.Mute,
        )
    }
}

// ── Compare table ────────────────────────────────────────────────────

@Composable
fun CompareScreen(onNext: () -> Unit) {
    val rows = listOf(
        R.string.funnel_compare_row1, R.string.funnel_compare_row2,
        R.string.funnel_compare_row3, R.string.funnel_compare_row4,
        R.string.funnel_compare_row5, R.string.funnel_compare_row6,
    )
    FnlScreen(bottom = { FnlCTA(stringResource(R.string.funnel_continue_cta)) { onNext() } }) {
        FnlKick(stringResource(R.string.funnel_compare_kicker))
        Spacer(Modifier.height(14.dp))
        FnlHeadline(stringResource(R.string.funnel_compare_headline), size = 40)
        Spacer(Modifier.height(20.dp))

        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, P1.Line, RoundedCornerShape(18.dp)),
        ) {
            // Header
            Row(
                Modifier
                    .fillMaxWidth()
                    .background(P1.Panel2)
                    .padding(horizontal = 18.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.funnel_compare_col_feature),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.9f),
                    color = P1.Mute,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    stringResource(R.string.funnel_compare_col_others),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.9f),
                    color = P1.Mute,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(60.dp),
                )
                Text(
                    stringResource(R.string.funnel_compare_col_pick1),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.9f),
                    color = P1.LimeFunnel,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(60.dp),
                )
            }
            rows.forEachIndexed { i, r ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .background(P1.Panel)
                        .padding(horizontal = 18.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        stringResource(r),
                        style = archivo(13, FontWeight.Medium),
                        color = P1.Foreground,
                        modifier = Modifier.weight(1f),
                    )
                    Box(Modifier.width(60.dp), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Close, null, tint = P1.Hot, modifier = Modifier.size(18.dp))
                    }
                    Box(Modifier.width(60.dp), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Check, null, tint = P1.Win, modifier = Modifier.size(18.dp))
                    }
                }
                if (i < rows.lastIndex) {
                    Box(Modifier.fillMaxWidth().height(1.dp).background(P1.Line))
                }
            }
        }
    }
}
