package com.pick1.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.home.P1_SPORTS
import com.pick1.app.ui.home.Pick1Wordmark
import com.pick1.app.ui.home.V4
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/**
 * The pick ticket, ported from `Pick1PickTicket.swift`.
 *
 * This is the object the product is about: one call, logged before kickoff,
 * with its terms printed on it. The detail page shows it and the share card
 * shows the SAME component tilted, so what people pass around cannot drift
 * away from what the app displays.
 */

/**
 * Rounded card with a notch bitten out of each side, at [notchY] from the top.
 * Drawn as one continuous path rather than by subtracting circles, so the
 * stroked outline follows the bite instead of drawing two full circles
 * hanging off the edges.
 */
class P1TicketShape(
    private val notchY: Float,
    private val notchR: Float = 9f,
    private val radius: Float = 20f,
) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val r = Rect(Offset.Zero, size)
        val y = r.top + notchY
        val p = Path().apply {
            moveTo(r.left + radius, r.top)
            lineTo(r.right - radius, r.top)
            quadraticBezierTo(r.right, r.top, r.right, r.top + radius)

            // Right bite. Sweeping back into the card is the bite; the other
            // direction balloons it outwards into a tab.
            lineTo(r.right, y - notchR)
            arcTo(
                Rect(r.right - notchR, y - notchR, r.right + notchR, y + notchR),
                -90f, 180f, false,
            )

            lineTo(r.right, r.bottom - radius)
            quadraticBezierTo(r.right, r.bottom, r.right - radius, r.bottom)
            lineTo(r.left + radius, r.bottom)
            quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - radius)

            // Left bite, mirrored.
            lineTo(r.left, y + notchR)
            arcTo(
                Rect(r.left - notchR, y - notchR, r.left + notchR, y + notchR),
                90f, 180f, false,
            )

            lineTo(r.left, r.top + radius)
            quadraticBezierTo(r.left, r.top, r.left + radius, r.top)
            close()
        }
        return Outline.Generic(p)
    }
}

/** The perforation the notches sit on. */
@Composable
private fun Perforation() {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .height(1.dp)
            .drawBehind {
                drawLine(
                    color = Color.White.copy(alpha = 0.18f),
                    start = Offset(0f, 0f),
                    end = Offset(size.width, 0f),
                    strokeWidth = 1f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f, 4f)),
                )
            },
    )
}

@Composable
fun P1PickTicket(
    pick: Pick,
    /** Live/final score when there is one, so a settled ticket carries the
     *  result rather than a stale kickoff time. */
    homeScore: Int? = null,
    awayScore: Int? = null,
    isLive: Boolean = false,
    confidence: String,
    loggedAt: String,
    modifier: Modifier = Modifier,
) {
    val stub = 52f
    val settled = pick.isWin || pick.isLoss
    val opponent = if (pick.pick.lowercase().contains(pick.homeTeam.lowercase())) {
        pick.awayTeam
    } else pick.homeTeam
    val isFieldEvent = pick.sport == "f1" || pick.sport == "golf" ||
        pick.awayTeam.equals("field", true) || pick.homeTeam.equals("field", true)
    val hasMarketOdds = (pick.marketOdds ?: 0.0) > 1.0
    val odds = pick.marketOdds ?: pick.impliedOddsForPayout ?: 0.0
    val stampText = if (pick.isWin) "WIN" else if (pick.isLoss) "LOSS" else null
    val stampColor = if (pick.isWin) V4.win else Color(0xFFFF5A36)
    val shape = P1TicketShape(notchY = stub)

    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Brush.verticalGradient(listOf(V4.panelTop, V4.panelBot)))
            .border(
                1.dp,
                if (settled) stampColor.copy(alpha = 0.4f) else P1.Lime.copy(alpha = 0.30f),
                shape,
            ),
    ) {
        // ── Stub ──────────────────────────────────────────────────────
        // The wordmark, not a serial number. The stub used to print four hex
        // characters off the pick's UUID: real-ticket texture that told the
        // reader nothing and, on a shared image, occupied the one spot where
        // the brand should be.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().height(stub.dp).padding(horizontal = 18.dp),
        ) {
            Pick1Wordmark(size = 17)
            Spacer(Modifier.weight(1f))
            Text(
                listOfNotNull(pick.league.uppercase(), pick.startTime).joinToString(" · "),
                style = mono(9, FontWeight.Bold, tracking = 0.6f),
                color = V4.mute,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Perforation()

        Column(Modifier.padding(horizontal = 18.dp).padding(bottom = 18.dp)) {
            // ── The call ──────────────────────────────────────────────
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            ) {
                TeamLogo(pick.sport, pick.pick, pick.homeLogo, size = 40)
                Column(Modifier.weight(1f).padding(start = 12.dp)) {
                    Text(
                        Sport.short(pick.pick),
                        style = anton(30, tracking = -0.2f),
                        color = P1.Foreground,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        if (isFieldEvent) "TO WIN · ${pick.homeTeam.uppercase()}"
                        else "TO WIN · vs ${Sport.short(opponent)}",
                        style = archivoNarrow(10, FontWeight.Bold, tracking = 1.4f),
                        color = V4.mute,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }

                // The outcome stamp is a layout sibling, not an overlay. As an
                // overlay it landed on the score pill and ate the end of it.
                if (stampText != null) {
                    Box(
                        Modifier
                            .rotate(-9f)
                            .border(2.5.dp, stampColor.copy(alpha = 0.75f), RoundedCornerShape(5.dp))
                            .padding(horizontal = 10.dp, vertical = 3.dp),
                    ) {
                        Text(stampText, style = anton(22, tracking = 1.6f), color = stampColor)
                    }
                }
            }

            // ── Terms ─────────────────────────────────────────────────
            Box(Modifier.fillMaxWidth().padding(top = 8.dp).height(1.dp).background(V4.line))

            Row(
                verticalAlignment = Alignment.Top,
                modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
            ) {
                Term(
                    "CONFIDENCE",
                    "${pick.probability.roundToInt()}%",
                    sub = confidence,
                    color = V4.win,
                    modifier = Modifier.weight(1f),
                )
                Box(Modifier.width(1.dp).height(34.dp).background(V4.line))
                when {
                    homeScore != null && awayScore != null && (settled || isLive) ->
                        Term(
                            if (isLive) "SCORE" else "FINAL",
                            "$homeScore–$awayScore",
                            sub = null,
                            color = P1.Foreground,
                            trailing = true,
                            modifier = Modifier.weight(1f),
                        )
                    // A real, executable price. The only case that earns the
                    // big money treatment.
                    hasMarketOdds ->
                        Term(
                            "RETURNS",
                            "$" + (100 * odds).roundToInt(),
                            sub = (pick.oddsSource ?: "MARKET ODDS").uppercase(),
                            color = P1.Lime,
                            trailing = true,
                            modifier = Modifier.weight(1f),
                        )
                    // No quote to compare against. Say so plainly instead of
                    // printing our own probability back as a price.
                    else ->
                        Term(
                            "NO MARKET",
                            String.format("%.2fx", odds),
                            sub = "EST. FROM CONFIDENCE",
                            color = V4.ink2,
                            trailing = true,
                            modifier = Modifier.weight(1f),
                        )
                }
            }

            Text(
                "LOGGED $loggedAt",
                style = mono(9, FontWeight.Medium, tracking = 0.8f),
                color = V4.mute,
                modifier = Modifier.padding(top = 12.dp),
            )
        }
    }
}

@Composable
private fun Term(
    label: String,
    value: String,
    sub: String?,
    color: Color,
    trailing: Boolean = false,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = if (trailing) Alignment.End else Alignment.Start,
        modifier = modifier,
    ) {
        Text(
            label.uppercase(),
            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.5f),
            color = V4.mute,
            maxLines = 1,
        )
        Text(value, style = anton(26), color = color, maxLines = 1, overflow = TextOverflow.Ellipsis)
        sub?.let {
            Text(
                it.uppercase(),
                style = mono(8, FontWeight.Bold, tracking = 0.6f),
                color = V4.mute,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** Confidence tier text, mirroring the iOS detail page exactly. */
fun confidenceTierText(pick: Pick): String {
    val raw = pick.confidence.lowercase()
    if (raw in listOf("high", "medium", "low")) return raw.replaceFirstChar { it.uppercase() }
    return when {
        pick.probability >= 70 -> "High"
        pick.probability >= 58 -> "Medium"
        else -> "Low"
    }
}
