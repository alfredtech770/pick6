package com.pick1.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.R
import com.pick1.app.billing.PlaceholderCatalogue
import com.pick1.app.data.PicksRepository
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.components.ProSlateCard
import com.pick1.app.ui.detail.MatchDetailScreen
import com.pick1.app.ui.free.FreeFeed
import com.pick1.app.ui.free.FreeMatchDetailScreen
import com.pick1.app.ui.history.PredictionHistoryScreen
import com.pick1.app.ui.free.FreeSlateSection
import com.pick1.app.ui.free.LatestWinsRail
import com.pick1.app.ui.free.MembersWonCard
import com.pick1.app.ui.free.PremiumUpsellCard
import com.pick1.app.ui.paywall.PaywallScreen
import com.pick1.app.ui.summerfootball.SummerFootballBanner
import com.pick1.app.ui.summerfootball.SummerFootballScreen
import com.pick1.app.ui.theme.*
import com.posthog.PostHog
import kotlinx.coroutines.launch

/**
 * Home board — port of `Pick1HomeHiFi.swift`.
 *
 * Structure matches iOS: the HERO card (today's highest-probability pick)
 * with the SportDropdown overlaid on its top-right, then either the pro
 * slate or the free-tier proof/tease/close stack.
 */
class HomeViewModel : ViewModel() {
    private val repo = PicksRepository()

    /** Today's slate — what the board is actually about. */
    var todayPicks by mutableStateOf<List<Pick>>(emptyList()); private set

    /** Recently graded results — feeds the Latest Wins proof rail. */
    var history by mutableStateOf<List<Pick>>(emptyList()); private set

    var loading by mutableStateOf(true); private set
    var error by mutableStateOf<String?>(null); private set
    var sport by mutableStateOf("all"); private set

    /**
     * Entitlement. Play Billing isn't wired yet, so the app runs in the FREE
     * tier — which is the surface we want to verify first.
     */
    var isPro by mutableStateOf(false); private set
    fun updateEntitlement(pro: Boolean) { isPro = pro }

    /** Sports present in today's slate, in the iOS carousel order. */
    val sports: List<String>
        get() {
            val order = listOf(
                "soccer", "baseball", "golf", "f1", "combat",
                "cricket", "basketball", "hockey", "tennis",
            )
            val present = todayPicks.map { it.sport }.toSet()
            return order.filter { it in present }
        }

    fun countFor(s: String): Int =
        if (s == "all") todayPicks.size else todayPicks.count { it.sport == s }

    val filteredToday: List<Pick>
        get() = if (sport == "all") todayPicks else todayPicks.filter { it.sport == sport }

    /** Highest-probability pick from today — the hero. */
    val topPick: Pick? get() = filteredToday.maxByOrNull { it.probability }

    fun select(s: String) {
        sport = s
        PostHog.capture("sport_selected", properties = mapOf("sport" to s))
    }

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            loading = true
            runCatching {
                val today = repo.todayPicks()
                val hist = repo.gradedHistory(limit = 60)
                today to hist
            }.onSuccess { (t, h) ->
                todayPicks = t; history = h; error = null
            }.onFailure { error = it.message }
            loading = false
        }
    }
}

@Composable
fun HomeScreen(vm: HomeViewModel = viewModel()) {
    var selected by remember { mutableStateOf<Pick?>(null) }
    var showPaywall by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var showSummerFootball by remember { mutableStateOf(false) }
    var showHistory by remember { mutableStateOf(false) }

    selected?.let { p ->
        // Free tier sees the tease detail (matchup shown, call locked);
        // Pro sees the real breakdown. Same split as iOS.
        if (vm.isPro) {
            MatchDetailScreen(p) { selected = null }
        } else {
            FreeMatchDetailScreen(
                pick = p,
                onClose = { selected = null },
                onUnlock = { selected = null; showPaywall = true },
            )
        }
        return
    }
    if (showHistory) {
        PredictionHistoryScreen(
            onClose = { showHistory = false },
            onTapPick = { showHistory = false; selected = it },
        )
        return
    }
    if (showSummerFootball) {
        SummerFootballScreen(
            isPro = vm.isPro,
            onClose = { showSummerFootball = false },
            onUnlock = { showSummerFootball = false; showPaywall = true },
            onTapPick = { selected = it },
        )
        return
    }
    if (showPaywall) {
        PaywallScreen(
            plans = PlaceholderCatalogue.plans(trialEligible = true),
            trialEligible = true,
            onBuy = { },
            onRestore = { },
            onContinueFree = { showPaywall = false },
        )
        return
    }

    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        when {
            vm.loading && vm.todayPicks.isEmpty() -> Box(Modifier.fillMaxSize(), Alignment.Center) {
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
                    Text(vm.error ?: "", style = archivo(12), color = P1.Mute)
                }
            }

            else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                // ── HERO + dropdown ──────────────────────────────────
                item {
                    Box {
                        Box(
                            Modifier.clickable(enabled = vm.topPick != null) {
                                vm.topPick?.let { selected = it }
                            }
                        ) {
                            HeroCard(vm.topPick)
                        }
                        // Overlaid OUTSIDE the hero's click target so menu
                        // taps never open the detail card.
                        SportDropdown(
                            sports = vm.sports,
                            selected = vm.sport,
                            countFor = vm::countFor,
                            isOpen = menuOpen,
                            onToggle = { menuOpen = !menuOpen },
                            onSelect = { vm.select(it); menuOpen = false },
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(end = 22.dp, top = 82.dp)
                                .zIndex(100f),
                        )
                    }
                }

                if (vm.isPro) {
                    item {
                        Text(
                            stringResource(R.string.rd_todays_games),
                            style = anton(22),
                            color = P1.Foreground,
                            modifier = Modifier.padding(horizontal = 20.dp),
                        )
                    }
                    items(
                        vm.filteredToday.filter { it.id != vm.topPick?.id },
                        key = { it.id },
                    ) { p ->
                        Box(Modifier.padding(horizontal = 20.dp)) {
                            ProSlateCard(p) { selected = p }
                        }
                    }
                } else {
                    // ── FREE TIER: proof -> tease -> close ───────────
                    val wins = FreeFeed.latestWins(vm.history, vm.sport)
                    val slate = FreeFeed.lockedSlate(vm.filteredToday, vm.topPick?.id, vm.sport)
                    val net = FreeFeed.membersNet(vm.history)
                    val yWins = vm.history.count { it.isWin }
                    val yLoss = vm.history.count { it.isLoss }
                    item {
                        LatestWinsRail(
                            results = wins,
                            onSeeAll = { showHistory = true },
                            membersCard = if (yWins >= 3 && yWins > yLoss && net > 0) {
                                { MembersWonCard(yWins, yLoss, net) { showPaywall = true } }
                            } else null,
                        )
                    }
                    if (vm.todayPicks.any { it.league == "WC" }) {
                        item { SummerFootballBanner { showSummerFootball = true } }
                    }
                    item { FreeSlateSection(slate) { showPaywall = true } }
                    item { PremiumUpsellCard(trialEligible = true) { showPaywall = true } }
                }
                item { Spacer(Modifier.height(96.dp)) }
            }
        }
    }
}
