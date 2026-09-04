package com.pick1.app.ui.tracker

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.theme.*
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Bottom drawer for logging a stake on a pick, ported from `P1BetDrawer.swift`.
 *
 * Collapsed it is a bar pinned to the bottom showing the call and the payout
 * multiple; drag it up or tap it and it expands into stake entry.
 *
 * IMPORTANT: this does NOT place a wager. Pick1 is not a sportsbook, and that
 * positioning is what keeps it runnable on Meta. The drawer writes a row to
 * `user_bets` — the user logging a bet they placed elsewhere, so the app can
 * show them their own record. Every label says "track", never "place".
 *
 * Android had a stake sheet already but it was wired to nothing, so there was
 * no way to track a pick at all and the Your Picks tab could never fill.
 */
@Composable
fun P1BetDrawer(
    pick: Pick,
    accent: Color = P1.Lime,
    /** Opens on the stake entry rather than the collapsed bar. Used when the
     *  user arrived by tapping TRACK on a game row: they already committed to
     *  the action, so making them find and drag the handle is friction. */
    startExpanded: Boolean = false,
    isTracked: Boolean = false,
    onTrack: (Double?) -> Unit,
    onUntrack: () -> Unit = {},
    onDismiss: () -> Unit,
) {
    val collapsedHeight = 92f
    val expandedHeight = 396f

    var expanded by remember { mutableStateOf(startExpanded) }
    var drag by remember { mutableFloatStateOf(0f) }
    var stakeText by remember { mutableStateOf("") }

    val stake = stakeText.replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 }
    val odds = pick.marketOdds ?: pick.impliedOddsForPayout ?: 1.9

    val base = if (expanded) expandedHeight else collapsedHeight
    val target = (base - drag).coerceIn(collapsedHeight, expandedHeight)
    val height by animateFloatAsState(target, spring(dampingRatio = 0.86f), label = "drawer")
    val openness = ((height - collapsedHeight) / (expandedHeight - collapsedHeight))
        .coerceIn(0f, 1f)

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
        // Scrim only once the drawer is meaningfully open, so the collapsed
        // bar never blocks the page behind it.
        if (openness > 0.02f) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.55f * openness))
                    .then(
                        if (openness > 0.5f) {
                            Modifier.clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) { expanded = false }
                        } else Modifier,
                    ),
            )
        }

        Column(
            Modifier
                .fillMaxWidth()
                .height(height.dp)
                .clip(RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp))
                .draggable(
                    orientation = Orientation.Vertical,
                    state = rememberDraggableState { delta -> drag -= delta },
                    onDragStopped = { velocity ->
                        drag = 0f
                        // A fast flick commits regardless of distance;
                        // otherwise snap to the nearer end.
                        expanded = if (abs(velocity) > 700f) velocity < 0 else openness > 0.5f
                    },
                ),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier
                    .padding(top = 10.dp, bottom = 12.dp)
                    .width(40.dp)
                    .height(5.dp)
                    .clip(RoundedCornerShape(50))
                    .background(P1.Line2),
            )

            // ── Collapsed bar ────────────────────────────────────────
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded }
                    .padding(horizontal = 20.dp),
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (isTracked) "TRACKING" else "TRACK YOUR BET",
                        style = archivoNarrow(9, FontWeight.Bold, tracking = 1.44f),
                        color = if (isTracked) accent else P1.Mute,
                    )
                    Text(
                        pick.pick.uppercase(),
                        style = anton(19),
                        color = P1.Foreground,
                        maxLines = 1,
                    )
                }
                Column(horizontalAlignment = Alignment.End, modifier = Modifier.padding(end = 12.dp)) {
                    Text(
                        String.format("%.2f×", odds),
                        style = mono(15, FontWeight.Bold),
                        color = accent,
                    )
                    Text(
                        "PAYOUT",
                        style = archivoNarrow(8, FontWeight.Bold, tracking = 1.12f),
                        color = P1.Mute,
                    )
                }
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(34.dp)
                        .clip(RoundedCornerShape(50))
                        .background(accent)
                        .rotate(openness * 180f),
                ) {
                    Text("^", style = archivo(13, FontWeight.Bold), color = P1.Ink)
                }
            }

            // ── Expanded body ────────────────────────────────────────
            if (openness > 0.02f) {
                Column(
                    Modifier
                        .alpha(openness)
                        .padding(horizontal = 20.dp)
                        .padding(top = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(
                        stringResource(R.string.rd_bt_stake_sub),
                        style = archivo(12),
                        color = P1.Mute,
                    )

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(10, 25, 50, 100).forEach { amt ->
                            val on = stakeText == amt.toString()
                            Text(
                                "$$amt",
                                style = archivo(14, FontWeight.Bold),
                                color = if (on) P1.Ink else P1.Ink2,
                                textAlign = TextAlign.Center,
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (on) accent else P1.Panel2)
                                    .clickable { stakeText = amt.toString() }
                                    .padding(vertical = 11.dp),
                            )
                        }
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(P1.Panel2),
                    ) {
                        Text(
                            "$",
                            style = anton(20),
                            color = P1.Mute,
                            modifier = Modifier.padding(start = 14.dp),
                        )
                        TextField(
                            value = stakeText,
                            onValueChange = { stakeText = it.filter { c -> c.isDigit() || c == '.' || c == ',' } },
                            placeholder = {
                                Text(stringResource(R.string.rd_bt_amount), style = anton(20), color = P1.Mute)
                            },
                            singleLine = true,
                            textStyle = TextStyle(
                                fontFamily = Anton, fontSize = 20.sp, color = P1.Foreground,
                            ),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent,
                                cursorColor = accent,
                            ),
                            modifier = Modifier.weight(1f),
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(R.string.rd_bt_to_return),
                            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.44f),
                            color = P1.Mute,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            stake?.let { "$" + (it * odds).roundToInt() } ?: "—",
                            style = anton(18),
                            color = accent,
                        )
                    }

                    Text(
                        stringResource(
                            if (stake == null) R.string.rd_bt_track_without_stake
                            else R.string.rd_bt_track_this,
                        ),
                        style = archivoNarrow(13, FontWeight.Bold, tracking = 1.56f),
                        color = P1.Ink,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(accent)
                            .clickable { onTrack(stake); onDismiss() }
                            .padding(vertical = 15.dp),
                    )

                    if (isTracked) {
                        Text(
                            "STOP TRACKING",
                            style = archivoNarrow(12, FontWeight.Bold, tracking = 1.5f),
                            color = Color(0xFFFF5A36),
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onUntrack(); onDismiss() }
                                .padding(vertical = 8.dp),
                        )
                    }
                }
            }
        }
    }
}
