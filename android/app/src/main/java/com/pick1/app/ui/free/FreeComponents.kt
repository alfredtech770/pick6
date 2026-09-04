package com.pick1.app.ui.free

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/** The gold used across every free-tier upsell surface. */
val Gold = Color(0xFFE8C64A)

/**
 * LATEST WINS rail — proof-first horizontal receipts.
 * Port of `LatestWinsRail` + `WinReceiptCard` (Pick1HomeHiFi.swift).
 */
@Composable
fun LatestWinsRail(
    results: List<Pick>,
    onSeeAll: () -> Unit,
    membersCard: (@Composable () -> Unit)? = null,
) {
    if (results.isEmpty()) return
    Column(Modifier.padding(bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .clickable { onSeeAll() },
            verticalAlignment = Alignment.Bottom,
        ) {
            Text(stringResource(R.string.rd_latest_wins), style = anton(22), color = Color.White)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.rd_see_all),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
                color = P1.Lime,
            )
        }
        LazyRow(
            contentPadding = PaddingValues(horizontal = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(results, key = { it.id }) { WinReceiptCard(it, onSeeAll) }
            membersCard?.let { item { it() } }
        }
    }
}

/** One receipt: the pick, the score line, our %, and the $100 return. */
@Composable
private fun WinReceiptCard(pick: Pick, onTap: () -> Unit) {
    val accent = if (pick.isWin) P1.Lime else P1.Loss
    Column(
        Modifier
            .width(170.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(P1.Panel)
            .border(1.dp, accent.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable { onTap() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        // Wins carry no header — the lime tint says it. Losses are labelled
        // explicitly so the rail reads honestly.
        if (!pick.isWin) {
            Text(
                "${stringResource(R.string.rd_missed_win)} · ${pick.league.uppercase()}",
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.2f),
                color = accent,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            pick.pick.uppercase(),
            style = anton(23),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (pick.homeScore != null && pick.awayScore != null)
                    "${pick.awayScore}–${pick.homeScore}" else pick.league.uppercase(),
                style = mono(12, FontWeight.Medium),
                color = Color(0xFF8A8D94),
            )
            Spacer(Modifier.weight(1f))
            Text(
                "${pick.probability.roundToInt()}%",
                style = archivo(13, FontWeight.Bold),
                color = accent,
            )
        }
        if (pick.isWin) {
            Text(
                "$100 → $${(pick.decimalOdds * 100).roundToInt()}",
                style = mono(12, FontWeight.Bold),
                color = accent,
            )
        }
    }
}

/**
 * The "MEMBERS WON MORE" regret card that closes the rail on free —
 * yesterday's member slate with flat-$100 math. Tap → paywall.
 */
@Composable
fun MembersWonCard(wins: Int, losses: Int, net: Int, onUnlock: () -> Unit) {
    Column(
        Modifier
            .width(170.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFF14110A))
            .border(1.dp, Gold.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .clickable { onUnlock() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            stringResource(R.string.sw_members_title),
            style = anton(15),
            color = Gold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text("$wins–$losses", style = anton(26), color = Color.White)
        Text("$100 → +$$net", style = mono(12, FontWeight.Bold), color = Gold)
        Row(
            Modifier
                .clip(CircleShape)
                .background(Gold)
                .padding(horizontal = 10.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(Icons.Default.LockOpen, null, tint = P1.Ink, modifier = Modifier.size(9.dp))
            Text(
                stringResource(R.string.rd_unlock),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = P1.Ink,
            )
        }
    }
}

/**
 * FULL SLATE (locked) — teases the depth of the board without giving the
 * matchup away. Port of `FreeSlateSection` + `LockedSlateCard`.
 */
@Composable
fun FreeSlateSection(slate: List<Pick>, onUnlock: (Pick) -> Unit) {
    if (slate.isEmpty()) return
    Column(
        Modifier.padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            Text(stringResource(R.string.rd_full_slate), style = anton(22), color = Color.White)
            Spacer(Modifier.weight(1f))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Icon(Icons.Default.Lock, null, tint = Gold, modifier = Modifier.size(10.dp))
                Text(
                    stringResource(R.string.rd_premium),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 2.0f),
                    color = Gold,
                )
            }
        }
        // Featured + 3 teasers — enough to show the board is deep.
        slate.take(3).forEach { LockedSlateCard(it) { onUnlock(it) } }
    }
}

@Composable
private fun LockedSlateCard(pick: Pick, onUnlock: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(P1.Panel)
            .border(1.dp, P1.Line, RoundedCornerShape(18.dp))
            .clickable { onUnlock() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                pick.league.uppercase(),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = Color(0xFF8A8D94),
            )
            Spacer(Modifier.weight(1f))
            pick.startTime?.let {
                Text(it, style = mono(11, FontWeight.Bold), color = Color(0xFF8A8D94))
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 44)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(color = Color.White)) { append(Sport.short(pick.awayTeam)) }
                        withStyle(SpanStyle(color = Gold.copy(alpha = 0.8f))) { append("  VS  ") }
                        withStyle(SpanStyle(color = Color.White)) { append(Sport.short(pick.homeTeam)) }
                    },
                    style = anton(17),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Icon(Icons.Default.Lock, null, tint = Gold, modifier = Modifier.size(8.dp))
                    Text(
                        stringResource(R.string.rd_ai_pick_hidden),
                        style = archivoNarrow(10, FontWeight.Bold, tracking = 1.4f),
                        color = Gold,
                    )
                }
            }
            Column(
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .border(1.dp, Gold.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 13.dp, vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Icon(Icons.Default.Lock, null, tint = Gold, modifier = Modifier.size(11.dp))
                Text(
                    stringResource(R.string.rd_unlock),
                    style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                    color = Gold,
                )
            }
        }
    }
}

/**
 * The gold PREMIUM upsell that closes the free home.
 * Port of `PremiumUpsellCard` — gradient card, radial gold glow, 4 checks,
 * gradient CTA and the price fine print.
 */
@Composable
fun PremiumUpsellCard(trialEligible: Boolean, onUnlock: () -> Unit) {
    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.linearGradient(
                    listOf(Color(0xFF1A160A), Color(0xFF0F0D07)),
                    start = Offset.Zero,
                    end = Offset.Infinite,
                )
            )
            .background(
                Brush.radialGradient(
                    listOf(Gold.copy(alpha = 0.16f), Color.Transparent),
                    radius = 700f,
                )
            )
            .border(1.dp, Gold.copy(alpha = 0.40f), RoundedCornerShape(22.dp))
            .clickable { onUnlock() }
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            stringResource(R.string.rd_prem_pill),
            style = archivoNarrow(11, FontWeight.Bold, tracking = 1.8f),
            color = Color(0xFF14110A),
            modifier = Modifier
                .clip(CircleShape)
                .background(Gold)
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
        val premHead = stringResource(R.string.rd_prem_head)
        val premAccent = stringResource(R.string.rd_prem_head_accent)
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = Color.White)) { append(premHead) }
                withStyle(SpanStyle(color = Gold)) { append(premAccent) }
            },
            style = anton(34),
        )
        Text(
            stringResource(R.string.rd_prem_body),
            style = archivo(13),
            color = P1.Ink2,
        )
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            CheckRow(stringResource(R.string.rd_prem_check1))
            CheckRow(stringResource(R.string.rd_prem_check2))
            CheckRow(stringResource(R.string.rd_prem_check3))
            CheckRow(stringResource(R.string.rd_prem_check4))
        }
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Text(
                stringResource(
                    if (trialEligible) R.string.rd_prem_cta_trial else R.string.rd_prem_cta
                ),
                style = anton(17, tracking = 0.4f),
                color = Color(0xFF14110A),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        Brush.verticalGradient(listOf(Color(0xFFF2D468), Gold))
                    )
                    .padding(vertical = 16.dp),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}

@Composable
private fun CheckRow(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        Icon(Icons.Default.Check, null, tint = Gold, modifier = Modifier.size(11.dp))
        Text(text, style = archivo(13, FontWeight.Medium), color = Color.White)
    }
}
