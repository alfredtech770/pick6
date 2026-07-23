package com.pick1.app.ui.tracker

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import com.pick1.app.R
import com.pick1.app.data.BetSummary
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.theme.*
import kotlin.math.abs
import kotlin.math.roundToInt

private val Win = Color(0xFFD4FF3A)

/**
 * Stake-entry sheet — port of `TrackBetSheet` (BetTrackerViews.swift).
 * Quick chips, a custom amount, the live TO RETURN figure, and a CTA that
 * changes label when no stake is entered.
 */
@Composable
fun TrackBetSheet(pick: Pick, accent: Color, onTrack: (Double?) -> Unit) {
    var stakeText by remember { mutableStateOf("") }
    val stake = stakeText.replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 }
    val odds = pick.marketOdds ?: pick.impliedOddsForPayout ?: 1.9

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .padding(22.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                stringResource(R.string.rd_bt_track_this),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.0f),
                color = P1.Mute,
            )
            Text(pick.pick, style = anton(22), color = P1.Foreground)
        }

        Text(
            stringResource(R.string.rd_bt_stake_sub),
            style = archivo(13),
            color = Color(0xFF8A8D94),
        )

        // Quick stake chips
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(10, 25, 50, 100).forEach { amt ->
                val active = stakeText == amt.toString()
                Text(
                    "$$amt",
                    style = archivo(14, FontWeight.Bold),
                    color = if (active) P1.Ink else P1.Ink2,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(if (active) accent else P1.Panel2)
                        .clickable { stakeText = amt.toString() }
                        .padding(vertical = 10.dp),
                )
            }
        }

        // Custom amount
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(P1.Panel2)
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("$", style = anton(20), color = P1.Mute)
            Box(Modifier.weight(1f)) {
                if (stakeText.isEmpty()) {
                    Text(stringResource(R.string.rd_bt_amount), style = anton(20), color = P1.Mute)
                }
                BasicTextField(
                    value = stakeText,
                    onValueChange = { stakeText = it.filter { c -> c.isDigit() || c == '.' || c == ',' } },
                    textStyle = anton(20).copy(color = P1.Foreground),
                    cursorBrush = SolidColor(accent),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                )
            }
        }

        if (stake != null) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.rd_bt_to_return),
                    style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                    color = P1.Mute,
                )
                Spacer(Modifier.weight(1f))
                Text("$${(stake * odds).roundToInt()}", style = anton(18), color = accent)
            }
        }

        Spacer(Modifier.weight(1f))

        Text(
            stringResource(
                if (stake == null) R.string.rd_bt_track_without_stake else R.string.rd_bt_track_bet
            ),
            style = archivoNarrow(13, FontWeight.Bold, tracking = 1.6f),
            color = P1.Ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(accent)
                .clickable { onTrack(stake) }
                .padding(vertical = 15.dp),
        )
    }
}

/**
 * Profile P&L card — port of `MyBetsCard`. Empty state until the user
 * tracks something, then the headline profit, ROI and the record row.
 */
@Composable
fun MyBetsCard(summary: BetSummary, modifier: Modifier = Modifier) {
    if (summary.tracked == 0) {
        Row(
            modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color(0xFF101216))
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.ShowChart, null, tint = P1.Mute, modifier = Modifier.size(18.dp))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    stringResource(R.string.rd_bt_ledger),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
                    color = P1.Ink2,
                )
                Text(
                    stringResource(R.string.rd_bt_empty),
                    style = archivo(12),
                    color = P1.Mute,
                )
            }
        }
        return
    }

    val profitColor = if (summary.profit >= 0) Win else P1.Loss
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFF101216))
            .border(1.dp, Color(0xFF1C1F25), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.rd_bt_ledger),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
                color = P1.Ink2,
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.rd_bt_n_tracked, summary.tracked),
                style = archivoNarrow(9, FontWeight.Bold, tracking = 1.2f),
                color = P1.Mute,
            )
        }

        if (summary.staked > 0) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    if (summary.profit >= 0) "+$${summary.profit.roundToInt()}"
                    else "-$${abs(summary.profit).roundToInt()}",
                    style = anton(34),
                    color = profitColor,
                )
                summary.roiPct?.let {
                    Text(
                        "${if (it >= 0) "+" else ""}${it.roundToInt()}% ROI",
                        style = archivo(13, FontWeight.Bold),
                        color = profitColor.copy(alpha = 0.85f),
                    )
                }
            }
            Text(
                "${stringResource(R.string.rd_bt_on)} $${summary.staked.roundToInt()} " +
                    stringResource(R.string.rd_bt_staked_across, summary.settled),
                style = archivo(11),
                color = P1.Mute,
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            StatCell(stringResource(R.string.rd_bt_record), "${summary.wins}-${summary.losses}", P1.Foreground)
            VDivider()
            StatCell(
                stringResource(R.string.rd_bt_hit_rate),
                summary.hitRate?.let { "$it%" } ?: "—",
                Win,
            )
            VDivider()
            StatCell(stringResource(R.string.rd_bt_pending), "${summary.pending}", P1.Ink2)
        }
    }
}

@Composable
private fun RowScope.StatCell(label: String, value: String, color: Color) {
    Column(
        Modifier.weight(1f),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text(value, style = anton(19), color = color)
        Text(
            label,
            style = archivoNarrow(8, FontWeight.Bold, tracking = 1.2f),
            color = P1.Mute,
        )
    }
}

@Composable
private fun VDivider() {
    Box(
        Modifier
            .width(1.dp)
            .height(30.dp)
            .background(Color(0xFF1C1F25)),
    )
}
