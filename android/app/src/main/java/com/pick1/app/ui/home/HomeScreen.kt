package com.pick1.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.ProSlateCard
import com.pick1.app.ui.detail.MatchDetailScreen
import com.pick1.app.ui.free.FreeFeed
import com.pick1.app.ui.free.FreeSlateSection
import com.pick1.app.ui.free.LatestWinsRail
import com.pick1.app.ui.free.MembersWonCard
import com.pick1.app.ui.free.PremiumUpsellCard
import com.pick1.app.ui.paywall.PaywallScreen
import com.pick1.app.billing.PlaceholderCatalogue
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.launch

/**
 * Home board — port of `Pick1HomeHiFi.swift`.
 *
 * Structure mirrors iOS: PICK1 wordmark, a horizontal sport filter scroller
 * (tennis included), then the slate of ProSlateCards.
 */
class HomeViewModel : ViewModel() {
    private val repo = PicksRepository()

    var picks by mutableStateOf<List<Pick>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var error by mutableStateOf<String?>(null); private set
    var sport by mutableStateOf("all"); private set

    /**
     * Entitlement. Play Billing isn't wired yet, so the app runs in the FREE
     * tier — which is exactly the surface we want to build and verify first.
     */
    var isPro by mutableStateOf(false); private set
    fun updateEntitlement(pro: Boolean) { isPro = pro }

    /** Sports present in the current slate, in the iOS carousel order. */
    val sports: List<String>
        get() {
            val order = listOf(
                "soccer", "baseball", "golf", "f1", "combat",
                "cricket", "basketball", "hockey", "tennis",
            )
            val present = picks.map { it.sport }.toSet()
            return listOf("all") + order.filter { it in present }
        }

    val visiblePicks: List<Pick>
        get() = if (sport == "all") picks else picks.filter { it.sport == sport }

    fun select(s: String) { sport = s }

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            loading = true
            runCatching { repo.latestWins(limit = 40) }
                .onSuccess { picks = it; error = null }
                .onFailure { error = it.message }
            loading = false
        }
    }
}

@Composable
fun HomeScreen(vm: HomeViewModel = viewModel()) {
    var selected by remember { mutableStateOf<Pick?>(null) }
    var showPaywall by remember { mutableStateOf(false) }

    if (showPaywall) {
        PaywallScreen(
            plans = PlaceholderCatalogue.plans(trialEligible = true),
            trialEligible = true,
            onBuy = { /* Play Billing purchase flow lands with the Play Console setup */ },
            onRestore = { },
            onContinueFree = { showPaywall = false },
        )
        return
    }
    selected?.let { p ->
        MatchDetailScreen(p) { selected = null }
        return
    }
    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding(),
    ) {
        Header()
        Spacer(Modifier.height(14.dp))

        if (vm.sports.size > 1) {
            SportScroller(
                sports = vm.sports,
                selected = vm.sport,
                onSelect = vm::select,
            )
            Spacer(Modifier.height(14.dp))
        }

        when {
            vm.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator(color = P1.Lime)
            }

            vm.error != null -> Box(Modifier.fillMaxSize(), Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        stringResource(R.string.state_offline_title),
                        style = anton(18),
                        color = P1.Foreground,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        vm.error ?: "",
                        style = archivo(12),
                        color = P1.Mute,
                    )
                }
            }

            vm.isPro -> LazyColumn(
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(vm.visiblePicks, key = { it.id }) { p -> ProSlateCard(p) { selected = p } }
                item { Spacer(Modifier.height(24.dp)) }
            }

            // ── FREE TIER ────────────────────────────────────────────
            // Proof (Latest Wins) -> tease (locked Full Slate) -> close
            // (gold Premium card). Same order as iOS.
            else -> {
                val wins = FreeFeed.latestWins(vm.picks, vm.sport)
                val slate = FreeFeed.lockedSlate(vm.visiblePicks, wins.firstOrNull()?.id, vm.sport)
                val net = FreeFeed.membersNet(vm.picks)
                val yWins = vm.picks.count { it.isWin }
                val yLoss = vm.picks.count { it.isLoss }
                LazyColumn(
                    contentPadding = PaddingValues(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    item {
                        LatestWinsRail(
                            results = wins,
                            onSeeAll = { },
                            membersCard = if (yWins >= 3 && yWins > yLoss && net > 0) {
                                { MembersWonCard(yWins, yLoss, net) { showPaywall = true } }
                            } else null,
                        )
                    }
                    item { FreeSlateSection(slate) { showPaywall = true } }
                    item { PremiumUpsellCard(trialEligible = true) { showPaywall = true } }
                    item { Spacer(Modifier.height(24.dp)) }
                }
            }
        }
    }
}

/** PICK1 wordmark + breadcrumb, matching the iOS header. */
@Composable
private fun Header() {
    Column(Modifier.padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text("PICK", style = anton(34, tracking = -0.34f), color = P1.Foreground)
            Text("1", style = anton(34, tracking = -0.34f), color = P1.Lime)
        }
        Text(
            stringResource(R.string.rd_picks_stats_glory),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
            color = P1.Mute,
        )
    }
}

/** Horizontal sport filter chips — the iOS carousel, including tennis. */
@Composable
private fun SportScroller(
    sports: List<String>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(sports) { s ->
            val active = s == selected
            val label = if (s == "all") stringResource(R.string.rd_all_filter)
            else "${Sport.emoji(s)} ${sportLabel(s)}"
            Text(
                label,
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.4f),
                color = if (active) P1.LimeInk else P1.Ink2,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (active) P1.Lime else P1.Panel)
                    .border(
                        1.dp,
                        if (active) Color.Transparent else P1.Line,
                        RoundedCornerShape(20.dp),
                    )
                    .clickable { onSelect(s) }
                    .padding(horizontal = 14.dp, vertical = 9.dp),
            )
        }
    }
}

/** Display names matching the iOS carousel labels. */
private fun sportLabel(sport: String): String = when (sport) {
    "baseball"   -> "MLB"
    "f1"         -> "F1"
    "combat"     -> "MMA"
    "soccer"     -> "Soccer"
    "golf"       -> "Golf"
    "cricket"    -> "Cricket"
    "basketball" -> "Basketball"
    "hockey"     -> "Hockey"
    "tennis"     -> "Tennis"
    else         -> sport.replaceFirstChar { it.uppercase() }
}
