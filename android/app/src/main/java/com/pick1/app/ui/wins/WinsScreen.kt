package com.pick1.app.ui.wins

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.data.Favorites
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.PageHero
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.components.TopCrumb
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * YOUR PICKS — port of `WinsView` (Pick1Screens.swift).
 *
 * Driven off the favorites store (not `result == "win"`) — that's what makes
 * starred matches actually land here, which was the iOS fix.
 */
class WinsViewModel : ViewModel() {
    private val repo = PicksRepository()
    var all by mutableStateOf<List<Pick>>(emptyList()); private set
    var loading by mutableStateOf(true); private set

    init {
        viewModelScope.launch {
            runCatching {
                // Favorites can be pending, won or lost — pull today's slate
                // plus recent history so any starred pick resolves.
                repo.todayPicks() + repo.gradedHistory(limit = 80)
            }.onSuccess { all = it.distinctBy { p -> p.id } }
            loading = false
        }
    }
}

@Composable
fun WinsScreen(vm: WinsViewModel = viewModel(), onTapPick: (Pick) -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val favIds by Favorites.ids(ctx).collectAsState(initial = emptySet())

    // Newest first, mirroring the iOS ordering.
    val saved = vm.all.filter { it.id in favIds }.sortedByDescending { it.gameDate }

    LazyColumn(Modifier.fillMaxSize().background(P1.Ink)) {
        item {
            Column(Modifier.safeDrawingPadding()) {
                TopCrumb(
                    crumb = stringResource(R.string.rd_crumb_you),
                    accent = stringResource(R.string.nav_picks).uppercase(),
                )
                PageHero(
                    title = stringResource(R.string.rd_your),
                    titleAccent = stringResource(R.string.rd_picks_word),
                    sub = listOf(
                        stringResource(R.string.rd_saved_matches, saved.size),
                        stringResource(R.string.rd_tap_star_favorite),
                    ),
                    glow = P1.Lime,
                )
                Spacer(Modifier.height(12.dp))
                if (saved.isNotEmpty()) {
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        Text(
                            stringResource(R.string.rd_clear_all),
                            style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                            color = P1.Loss,
                            modifier = Modifier.clickable { scope.launch { Favorites.clear(ctx) } },
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                }
            }
        }

        if (saved.isEmpty()) {
            item { EmptyState() }
        } else {
            items(saved, key = { it.id }) { p ->
                Box(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    SavedCard(p) { onTapPick(p) }
                }
            }
        }
        item { Spacer(Modifier.height(140.dp)) }
    }
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 50.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Default.StarBorder, null, tint = P1.Mute, modifier = Modifier.size(30.dp))
        Text(
            stringResource(R.string.rd_no_saved_title),
            style = anton(20),
            color = P1.Foreground,
            textAlign = TextAlign.Center,
        )
        Text(
            stringResource(R.string.rd_no_saved_sub),
            style = archivo(13),
            color = P1.Mute,
            textAlign = TextAlign.Center,
        )
    }
}

/** A saved pick with its outcome chip — W / L / pending. */
@Composable
private fun SavedCard(pick: Pick, onClick: () -> Unit) {
    val accent = when {
        pick.isWin -> P1.WinLime
        pick.isLoss -> P1.Loss
        else -> P1.Line
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(P1.Panel)
            .border(1.dp, accent.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "${Sport.emoji(pick.sport)} ${pick.league.uppercase()}",
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = Color(0xFF8A8D94),
            )
            Spacer(Modifier.weight(1f))
            val label = when {
                pick.isWin -> stringResource(R.string.rd_won)
                pick.isLoss -> stringResource(R.string.rd_lost)
                else -> stringResource(R.string.card_awaiting)
            }
            Text(
                label,
                style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                color = if (pick.isPending) P1.Mute else P1.Ink,
                modifier = if (pick.isPending) Modifier else Modifier
                    .clip(CircleShape)
                    .background(accent)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 40)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "${Sport.short(pick.awayTeam)}  ${stringResource(R.string.card_vs)}  ${Sport.short(pick.homeTeam)}",
                    style = anton(16),
                    color = P1.Foreground,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    pick.pick.uppercase(),
                    style = archivoNarrow(11, FontWeight.Bold, tracking = 1.2f),
                    color = P1.Lime,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text("${pick.probability.roundToInt()}%", style = anton(22), color = P1.Lime)
        }
    }
}
