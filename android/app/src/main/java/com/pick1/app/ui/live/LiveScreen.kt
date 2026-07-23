package com.pick1.app.ui.live

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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.data.Favorites
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.LiveScore
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.PageHero
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.components.TopCrumb
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * LIVE NOW — port of `LiveView` (Pick1Screens.swift).
 *
 * Joins today's picks to the `live_scores` table by game_id. One filter:
 * everything live (default) vs just the user's starred picks — the old
 * segmented tabs were cut on iOS, so they're deliberately absent here too.
 */
class LiveViewModel : ViewModel() {
    private val repo = PicksRepository()

    var picks by mutableStateOf<List<Pick>>(emptyList()); private set
    var scores by mutableStateOf<List<LiveScore>>(emptyList()); private set
    var loading by mutableStateOf(true); private set

    init {
        viewModelScope.launch {
            runCatching { repo.todayPicks() to repo.liveScores() }
                .onSuccess { (p, s) -> picks = p; scores = s }
            loading = false
        }
    }

    fun scoreFor(pick: Pick): LiveScore? =
        pick.gameId?.let { gid -> scores.firstOrNull { it.gameId == gid } }

    /** Today's picks whose game is in progress. */
    val livePicks: List<Pick>
        get() = picks.filter { scoreFor(it)?.isLive == true }
}

@Composable
fun LiveScreen(vm: LiveViewModel = viewModel(), onTapPick: (Pick) -> Unit) {
    val ctx = LocalContext.current
    val favIds by Favorites.ids(ctx).collectAsState(initial = emptySet())
    var favoritesOnly by remember { mutableStateOf(false) }

    val shown = if (favoritesOnly) vm.livePicks.filter { it.id in favIds } else vm.livePicks

    LazyColumn(Modifier.fillMaxSize().background(P1.Ink)) {
        item {
            Column(Modifier.safeDrawingPadding()) {
                TopCrumb(
                    crumb = stringResource(R.string.rd_crumb_now),
                    accent = stringResource(R.string.card_live),
                    live = vm.livePicks.isNotEmpty(),
                )
                PageHero(
                    title = stringResource(R.string.rd_live_word),
                    titleAccent = stringResource(R.string.rd_now_word),
                    sub = listOf(
                        stringResource(R.string.rd_games_n, vm.livePicks.size),
                        stringResource(R.string.rd_picks_in_play, vm.livePicks.size),
                    ),
                    glow = P1.Hot,
                )
                Spacer(Modifier.height(14.dp))
                // Single filter: ALL LIVE vs FAVORITES.
                Row(
                    Modifier.padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilterChip(stringResource(R.string.rd_in_play), !favoritesOnly) {
                        favoritesOnly = false
                    }
                    FilterChip(stringResource(R.string.rd_favorites), favoritesOnly) {
                        favoritesOnly = true
                    }
                }
                Spacer(Modifier.height(12.dp))
            }
        }

        if (shown.isEmpty()) {
            item {
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 40.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        stringResource(R.string.rd_no_games_today),
                        style = anton(20),
                        color = P1.Foreground,
                    )
                    Text(
                        stringResource(R.string.rd_picks_drop),
                        style = archivo(13),
                        color = P1.Mute,
                    )
                }
            }
        } else {
            items(shown, key = { it.id }) { p ->
                Box(Modifier.padding(horizontal = 16.dp, vertical = 5.dp)) {
                    LiveCard(p, vm.scoreFor(p)) { onTapPick(p) }
                }
            }
        }
        item { Spacer(Modifier.height(140.dp)) }
    }
}

@Composable
private fun FilterChip(label: String, active: Boolean, onClick: () -> Unit) {
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

/** A live game row: pulsing LIVE dot, running score, our call. */
@Composable
private fun LiveCard(pick: Pick, score: LiveScore?, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(P1.Panel)
            .border(1.dp, P1.Hot.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
            .clickable { onClick() }
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(P1.Hot))
            Spacer(Modifier.width(6.dp))
            Text(
                "${stringResource(R.string.card_live)} · ${pick.league.uppercase()}",
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.6f),
                color = P1.Hot,
            )
            Spacer(Modifier.weight(1f))
            score?.quarter?.let {
                Text(it, style = mono(10, FontWeight.Bold), color = P1.Mute)
            }
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
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
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
            // Running score, else our confidence.
            if (score?.homeScore != null && score.awayScore != null) {
                Text(
                    "${score.awayScore}–${score.homeScore}",
                    style = anton(24),
                    color = P1.Foreground,
                )
            } else {
                Text("${pick.probability.roundToInt()}%", style = anton(22), color = P1.Lime)
            }
        }
    }
}
