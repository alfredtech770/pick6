package com.pick1.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/**
 * The featured top pick — port of `HeroCard` (Pick1HomeHiFi.swift).
 *
 * A deep premium gradient (dark ink at the top fading into rich lime at the
 * bottom-right), bottom-rounded only so the card bleeds to the physical top
 * edge under the status bar, with the matchup marks, the call and the
 * probability sharing one baseline.
 */
@Composable
fun HeroCard(pick: Pick?, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(bottomStart = 32.dp, bottomEnd = 32.dp)
    Box(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                // Deep ink -> lime wash, anchored bottom-right.
                Brush.linearGradient(
                    0f to Color(0xFF0A0B0D),
                    0.55f to Color(0xFF16200A),
                    1f to Color(0xFF3D5410),
                    start = Offset.Zero,
                    end = Offset(900f, 1400f),
                )
            )
            // Bright top sheen.
            .background(
                Brush.verticalGradient(
                    0f to Color.White.copy(alpha = 0.05f),
                    0.10f to Color.Transparent,
                )
            ),
    ) {
        Column(
            Modifier
                .padding(horizontal = 22.dp)
                .padding(top = 68.dp, bottom = 26.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            // Wordmark row
            Row(verticalAlignment = Alignment.Bottom) {
                Text("PICK", style = anton(26, tracking = -0.26f), color = P1.Foreground)
                Text("1", style = anton(26, tracking = -0.26f), color = P1.Lime)
            }

            if (pick == null) {
                Text(
                    stringResource(R.string.rd_no_games_today),
                    style = anton(26),
                    color = P1.Foreground,
                )
                Text(
                    stringResource(R.string.rd_picks_drop),
                    style = archivo(13),
                    color = P1.Ink2,
                )
                return@Column
            }

            // ── Matchup marks ────────────────────────────────────────
            if (pick.isFieldEvent) {
                TeamLogo(pick.sport, pick.pick, null, size = 76)
            } else {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    HeroTeamColumn(pick.sport, pick.awayTeam, pick.awayLogo)
                    Text(
                        stringResource(R.string.card_vs),
                        style = anton(14),
                        color = Color.White.copy(alpha = 0.4f),
                        modifier = Modifier.padding(top = 30.dp),
                    )
                    HeroTeamColumn(pick.sport, pick.homeTeam, pick.homeLogo)
                }
            }

            // ── The call + the number, sharing one baseline ──────────
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.rd_ai_picks),
                        style = archivoNarrow(11, FontWeight.Bold, tracking = 2.4f),
                        color = Color(0xFF8A8D94),
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        stringResource(R.string.rd_win_prob),
                        style = archivoNarrow(11, FontWeight.Bold, tracking = 2.0f),
                        color = Color(0xFF8A8D94),
                    )
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    // iOS shrinks this to fit (minimumScaleFactor 0.45) rather
                    // than truncating, so a long pick name still reads in full.
                    val name = pick.pick.uppercase()
                    val heroSize = when {
                        name.length <= 9 -> 46
                        name.length <= 13 -> 36
                        name.length <= 18 -> 28
                        else -> 22
                    }
                    // The name takes all remaining width (iOS gives the
                    // percentage only a minLength-8 spacer, not half the row).
                    Text(
                        name,
                        style = anton(heroSize, tracking = -0.5f),
                        color = P1.Lime,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "${pick.probability.roundToInt()}%",
                        style = anton(46, tracking = -0.5f),
                        color = P1.Lime,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

/** One team: crest above its name, centred — the iOS heroTeamColumn. */
@Composable
private fun HeroTeamColumn(sport: String, team: String, logo: String?) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.width(104.dp),
    ) {
        TeamLogo(sport, team, logo, size = 54)
        Text(
            Sport.short(team).uppercase(),
            style = anton(14),
            color = P1.Foreground,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
