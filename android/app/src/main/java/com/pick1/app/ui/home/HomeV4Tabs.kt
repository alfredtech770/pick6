package com.pick1.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pick1.app.data.UserBet
import com.pick1.app.data.model.LiveScore
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.theme.*
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The LIVE / YOUR PICKS / RESULTS rows, ported from `Pick1HomeV4.swift`.
 *
 * These three lived behind a bottom navigation bar on Android and behind
 * header tabs on iOS, in different shapes. Same components now.
 */

private val hot = Color(0xFFFF5A36)
private val hotSoft = Color(0xFFFF8A6C)

// MARK: - Live card

@Composable
fun P1V4LiveCard(
    pick: Pick,
    score: LiveScore,
    tint: Color,
    /** A free user sees the game and the live score; what is withheld is the
     *  AI's call on it, which is the thing being sold. */
    isLocked: Boolean = false,
) {
    val calledIsHome = pick.pick.equals(pick.homeTeam, ignoreCase = true)

    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 16.dp)
            .clip(RoundedCornerShape(26.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF171B22), V4.panelBot)))
            .border(1.dp, tint.copy(alpha = 0.35f), RoundedCornerShape(26.dp))
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (isLocked) "${pick.league.uppercase()} · PICK LOCKED"
                else "${pick.league.uppercase()} · YOUR PICK: ${Sport.short(pick.pick).uppercase()} · ${pick.probability.roundToInt()}%",
                style = mono(8, FontWeight.Bold, tracking = 0.4f),
                color = V4.mute,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            (score.quarter ?: score.status)?.let {
                Text(
                    it.uppercase(),
                    style = mono(8, FontWeight.Bold, tracking = 0.4f),
                    color = V4.mute,
                    maxLines = 1,
                )
            }
        }

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
        ) {
            LiveTeam(pick.sport, score.awayTeam, isPick = !calledIsHome, isLocked = isLocked)
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "${score.awayScore ?: 0}–${score.homeScore ?: 0}",
                    style = anton(40),
                    color = P1.Foreground,
                    maxLines = 1,
                )
                score.quarter?.takeIf { it.isNotEmpty() }?.let {
                    Text(
                        it.uppercase(),
                        style = mono(9, FontWeight.Bold, tracking = 0.9f),
                        color = hotSoft,
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            LiveTeam(pick.sport, score.homeTeam, isPick = calledIsHome, isLocked = isLocked)
        }
    }
}

@Composable
private fun LiveTeam(sport: String, name: String, isPick: Boolean, isLocked: Boolean) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(82.dp),
    ) {
        Text(
            Sport.short(name).uppercase(),
            style = anton(21),
            color = if (isPick) P1.Lime else P1.Foreground,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
        Text(
            (if (isPick && !isLocked) "▸ " else "") + name.uppercase(),
            style = archivoNarrow(9, FontWeight.Bold, tracking = 0.9f),
            color = V4.mute,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
    }
}

// MARK: - Result row

/**
 * The MONEY is the headline and the verdict is the caption. "WIN" in a
 * capsule with the amount whispering underneath had the hierarchy backwards:
 * everyone already knows a green row won, what they came to read is what it
 * was worth. Wins AND losses are shareable — a record you can only pass on
 * when it flatters you is not a record.
 */
@Composable
fun P1V4ResultRow(
    pick: Pick,
    isHighlight: Boolean = false,
    onShare: (() -> Unit)? = null,
    onTap: () -> Unit,
) {
    val scoreLine = if (pick.homeScore != null && pick.awayScore != null) {
        "${max(pick.homeScore!!, pick.awayScore!!)}–${min(pick.homeScore!!, pick.awayScore!!)}"
    } else null

    // "+$139" on a winner, "−$100" on a loser, from the real settled price.
    val net = if (pick.isWin) (pick.decimalOdds - 1) * 100 else -100.0
    val returnLine = (if (net >= 0) "+$" else "−$") + abs(net).roundToInt()

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 10.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.linearGradient(
                    if (isHighlight) listOf(V4.gold.copy(alpha = 0.08f), V4.panelBot)
                    else listOf(V4.rowTop, V4.panelBot),
                ),
            )
            .border(
                1.dp,
                if (isHighlight) V4.gold.copy(alpha = 0.45f) else V4.line,
                RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onTap)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        com.pick1.app.ui.components.P1SportMark(pick.sport, size = 18)

        Column(Modifier.weight(1f).padding(start = 11.dp)) {
            Text(
                Sport.short(pick.pick).uppercase(),
                style = anton(13),
                color = P1.Foreground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                listOfNotNull(
                    scoreLine,
                    "CALLED AT ${pick.probability.roundToInt()}%",
                    pick.league.uppercase(),
                ).joinToString(" · "),
                style = mono(8, FontWeight.Bold, tracking = 0.43f),
                color = V4.mute,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Column(horizontalAlignment = Alignment.End) {
            Text(
                returnLine,
                style = anton(22),
                color = if (pick.isWin) V4.win else hotSoft,
                maxLines = 1,
            )
            Text(
                if (pick.isWin) "WIN" else "LOSS",
                style = archivoNarrow(8, FontWeight.Bold, tracking = 1.1f),
                color = V4.mute,
            )
        }

        if (onShare != null) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .padding(start = 11.dp)
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(V4.panelBot)
                    .border(1.dp, V4.line, CircleShape)
                    .clickable(onClick = onShare),
            ) {
                Icon(Icons.Default.Share, contentDescription = null, tint = V4.mute)
            }
        }
    }
}

// MARK: - Your-picks row

/**
 * One row of the user's own slate.
 *
 * The results row could not be reused: this list mixes picks that have not
 * played yet with settled ones, and when the user tracked a stake the row has
 * to say what that stake stands to return, or actually returned. A
 * starred-but-never-tracked pick simply has no money line.
 */
@Composable
fun P1V4YourRow(pick: Pick, bet: UserBet?, onTap: () -> Unit) {
    val odds = (bet?.oddsAtBet ?: pick.marketOdds ?: pick.impliedOddsForPayout)
        ?.takeIf { it > 1 }

    fun money(v: Double) = "$" + v.roundToInt()

    val stakeLine: String? = bet?.stake?.takeIf { it > 0 }?.let { stake ->
        odds?.let { o ->
            if (pick.isPending) "${money(stake)} → ${money(stake * o)}"
            else if (pick.isWin) "+${money(stake * (o - 1))}" else "−${money(stake)}"
        }
    }

    val chipText = if (pick.isPending) "TO PLAY" else if (pick.isWin) "WIN" else "LOSS"
    val chipColor = if (pick.isPending) V4.gold else if (pick.isWin) V4.win else hot

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 10.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.linearGradient(listOf(V4.rowTop, V4.panelBot)))
            .border(1.dp, V4.line, RoundedCornerShape(16.dp))
            .clickable(onClick = onTap)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        com.pick1.app.ui.components.P1SportMark(pick.sport, size = 18)

        Column(Modifier.weight(1f).padding(start = 11.dp)) {
            Text(
                Sport.short(pick.pick).uppercase(),
                style = anton(13),
                color = P1.Foreground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                listOf(
                    pick.league.uppercase(),
                    "CALLED AT ${pick.probability.roundToInt()}%",
                    if (bet == null) "STARRED" else "TRACKED",
                ).joinToString(" · "),
                style = mono(8, FontWeight.Bold, tracking = 0.43f),
                color = V4.mute,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Column(horizontalAlignment = Alignment.End) {
            Box(
                Modifier
                    .clip(RoundedCornerShape(50))
                    .background(chipColor.copy(alpha = 0.11f))
                    .border(1.dp, chipColor.copy(alpha = 0.45f), RoundedCornerShape(50))
                    .padding(horizontal = 11.dp, vertical = 5.dp),
            ) {
                Text(chipText, style = anton(12, tracking = 0.52f), color = chipColor)
            }
            stakeLine?.let {
                Text(
                    it,
                    style = mono(10, FontWeight.Bold),
                    color = if (pick.isPending) P1.Lime else if (pick.isWin) V4.win else hotSoft,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

// MARK: - Results header

/** The 30-day total, in money, on the stated flat stake. */
@Composable
fun P1V4MoneyStrip(net: Int, settled: Int) {
    val up = net >= 0
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp)
            .padding(top = 16.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.linearGradient(listOf(V4.rowTop, V4.panelBot)))
            .border(1.dp, V4.line, RoundedCornerShape(18.dp))
            .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        Text(
            (if (up) "+$" else "−$") + abs(net),
            style = anton(40),
            color = if (up) P1.Lime else hotSoft,
            maxLines = 1,
        )
        Text(
            "LAST 30 DAYS · $100 A CALL · $settled SETTLED",
            style = archivoNarrow(9, FontWeight.Bold, tracking = 0.9f),
            color = V4.mute,
            maxLines = 1,
        )
    }
}

@Composable
fun RowScope.P1V4ResultBox(value: String, label: String, flame: Boolean = false) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .weight(1f)
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.linearGradient(listOf(V4.rowTop, V4.panelBot)))
            .border(1.dp, V4.line, RoundedCornerShape(16.dp))
            .padding(horizontal = 10.dp, vertical = 14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // The flame appears from two in a row. Beside a 0 it contradicts
            // itself, and the streak is 0 whenever the most recent call lost.
            if (flame) Text("🔥", style = archivo(15), modifier = Modifier.padding(end = 4.dp))
            Text(value, style = anton(26), color = P1.Lime, maxLines = 1)
        }
        Text(
            label.uppercase(),
            style = archivoNarrow(8, FontWeight.Bold, tracking = 0.96f),
            color = V4.mute,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
fun P1V4EmptyState(title: String, body: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 40.dp, vertical = 60.dp),
    ) {
        Text(title, style = anton(18), color = P1.Foreground, textAlign = TextAlign.Center)
        Text(
            body,
            style = archivo(12),
            color = V4.mute,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}
