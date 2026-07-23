package com.pick1.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/**
 * The main pick card on the home board — a port of `ProSlateCard` in
 * `Pick1HomeHiFi.swift`.
 *
 * Layout (identical to iOS):
 *   ┌───────────────────────────────────────────────┐
 *   │ 🏀 NBA                        7:30 PM ET      │  league row
 *   │ ◯  LAL  VS  BOS               84%             │  crest · matchup · prob
 *   │    AI PICK  LAL ML            $100 → $184     │
 *   └───────────────────────────────────────────────┘
 * with an 18dp corner radius, a per-sport tint wash from the leading edge,
 * and a 1dp tinted border.
 */
@Composable
fun ProSlateCard(
    pick: Pick,
    modifier: Modifier = Modifier,
    trailingLabel: String? = null,
    onClick: (() -> Unit)? = null,
) {
    val tint = Sport.tint(pick.sport)
    val shape = RoundedCornerShape(18.dp)

    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .background(Color(0xFF0F1114))
            // Per-sport wash: leading edge → transparent by ~55% across.
            .background(
                Brush.horizontalGradient(
                    0f to tint.copy(alpha = 0.22f),
                    0.55f to Color.Transparent,
                )
            )
            .border(1.dp, tint.copy(alpha = 0.30f), shape)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // ── League row ───────────────────────────────────────────
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "${Sport.emoji(pick.sport)} ${pick.league.uppercase()}",
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = Color(0xFF8A8D94),
            )
            Spacer(Modifier.weight(1f))
            TopTrailing(pick, trailingLabel)
        }

        // ── Matchup row ──────────────────────────────────────────
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (pick.isFieldEvent) {
                // Golf/F1: feature the picked competitor, not a "VS" pair.
                TeamLogo(pick.sport, pick.pick, null, size = 44)
                Column(
                    Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(
                        pick.pick.uppercase(),
                        style = anton(17),
                        color = Color.White,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        pick.homeTeam.uppercase(),
                        style = archivoNarrow(10, FontWeight.Bold, tracking = 1.2f),
                        color = Color(0xFF8A8D94),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            } else {
                TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 44)
                Column(
                    Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(
                        buildAnnotatedString {
                            withStyle(SpanStyle(color = Color.White)) {
                                append(Sport.short(pick.awayTeam))
                            }
                            withStyle(SpanStyle(color = P1.Lime.copy(alpha = 0.75f))) {
                                append("  VS  ")
                            }
                            withStyle(SpanStyle(color = Color.White)) {
                                append(Sport.short(pick.homeTeam))
                            }
                        },
                        style = anton(17),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            stringResource(R.string.rd_ai_picks),
                            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.6f),
                            color = Color(0xFF8A8D94),
                        )
                        Text(
                            pick.pick.uppercase(),
                            style = archivoNarrow(11, FontWeight.Bold, tracking = 1.2f),
                            color = P1.Lime,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }

            // ── Probability + payout ─────────────────────────────
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    "${pick.probability.roundToInt()}%",
                    style = anton(24),
                    color = P1.Lime,
                )
                Text(
                    "$100 → $${(pick.decimalOdds * 100).roundToInt()}",
                    style = mono(10, FontWeight.Bold),
                    color = Color(0xFF8A8D94),
                )
            }
        }
    }
}

/**
 * Top-right slot: the settled W/L chip, or a caller-supplied label
 * (kickoff time). Live scores arrive with the live_scores wiring.
 */
@Composable
private fun TopTrailing(pick: Pick, trailingLabel: String?) {
    when {
        pick.isWin -> Chip(stringResource(R.string.rd_won), P1.WinLime)
        pick.isLoss -> Chip(stringResource(R.string.rd_lost), P1.Loss)
        trailingLabel != null -> Text(
            trailingLabel,
            style = mono(10, FontWeight.Bold),
            color = Color(0xFF8A8D94),
        )
        else -> Text(
            stringResource(R.string.card_awaiting),
            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
            color = Color(0xFF8A8D94),
        )
    }
}

@Composable
private fun Chip(label: String, color: Color) {
    Text(
        label,
        style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
        color = P1.Ink,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color)
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}
