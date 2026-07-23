package com.pick1.app.ui.history

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * The public ledger — port of `PredictionHistoryView` (Pick1Screens.swift).
 *
 * Every graded call, wins AND losses, with an ALL / WON / LOST filter and a
 * running record. Showing losses is the point: it's the honesty surface the
 * whole product leans on.
 */
private enum class HistoryFilter { ALL, WON, LOST }

class HistoryViewModel : ViewModel() {
    private val repo = PicksRepository()
    var picks by mutableStateOf<List<Pick>>(emptyList()); private set
    var loading by mutableStateOf(true); private set

    init {
        viewModelScope.launch {
            runCatching { repo.gradedHistory(limit = 120) }
                .onSuccess { picks = it.filter { p -> !p.isPending } }
            loading = false
        }
    }
}

@Composable
fun PredictionHistoryScreen(
    vm: HistoryViewModel = viewModel(),
    onClose: () -> Unit,
    onTapPick: (Pick) -> Unit,
) {
    var filter by remember { mutableStateOf(HistoryFilter.ALL) }
    val shown = when (filter) {
        HistoryFilter.ALL -> vm.picks
        HistoryFilter.WON -> vm.picks.filter { it.isWin }
        HistoryFilter.LOST -> vm.picks.filter { it.isLoss }
    }
    val wins = vm.picks.count { it.isWin }
    val losses = vm.picks.count { it.isLoss }

    Column(Modifier.fillMaxSize().background(P1.Ink).safeDrawingPadding()) {
        // Grabber + header
        Box(Modifier.fillMaxWidth().padding(top = 10.dp), contentAlignment = Alignment.Center) {
            Box(
                Modifier.width(42.dp).height(5.dp).clip(CircleShape).background(P1.Line2),
            )
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    stringResource(R.string.rd_record),
                    style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
                    color = P1.Mute,
                )
                Text("$wins–$losses", style = anton(26), color = P1.Foreground)
            }
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.action_done),
                style = archivo(13, FontWeight.Bold),
                color = P1.Lime,
                modifier = Modifier.clickable { onClose() },
            )
        }

        // Filter chips
        Row(
            Modifier.padding(horizontal = 16.dp).padding(bottom = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Chip(stringResource(R.string.rd_all_filter), filter == HistoryFilter.ALL) {
                filter = HistoryFilter.ALL
            }
            Chip(stringResource(R.string.rd_won), filter == HistoryFilter.WON) {
                filter = HistoryFilter.WON
            }
            Chip(stringResource(R.string.rd_lost), filter == HistoryFilter.LOST) {
                filter = HistoryFilter.LOST
            }
        }

        if (shown.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        stringResource(R.string.rd_no_graded_title),
                        style = anton(20),
                        color = P1.Foreground,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        stringResource(R.string.rd_no_graded_sub),
                        style = archivo(13),
                        color = P1.Mute,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(shown, key = { it.id }) { p -> HistoryRow(p) { onTapPick(p) } }
                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}

@Composable
private fun Chip(label: String, active: Boolean, onClick: () -> Unit) {
    Text(
        label,
        style = archivoNarrow(11, FontWeight.Bold, tracking = 1.4f),
        color = if (active) P1.LimeInk else P1.Ink2,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (active) P1.Lime else P1.Panel)
            .border(1.dp, if (active) Color.Transparent else P1.Line, RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 9.dp),
    )
}

@Composable
private fun HistoryRow(pick: Pick, onClick: () -> Unit) {
    val accent = if (pick.isWin) P1.WinLime else P1.Loss
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(P1.Panel)
            .border(1.dp, accent.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 36)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                pick.pick.uppercase(),
                style = anton(15),
                color = P1.Foreground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "${pick.league.uppercase()} · ${pick.gameDate}",
                style = mono(10, FontWeight.Medium),
                color = P1.Mute,
            )
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                stringResource(if (pick.isWin) R.string.rd_won else R.string.rd_lost),
                style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                color = P1.Ink,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(accent)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
            Text("${pick.probability.roundToInt()}%", style = mono(11, FontWeight.Bold), color = P1.Mute)
        }
    }
}
