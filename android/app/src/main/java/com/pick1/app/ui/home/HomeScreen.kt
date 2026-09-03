package com.pick1.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
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
import android.app.Activity
import androidx.compose.ui.platform.LocalContext
import com.pick1.app.R
import com.pick1.app.billing.Billing
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
import kotlin.math.roundToInt

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

    /** In-play scores, keyed to picks by game_id. */
    var liveScores by mutableStateOf<List<com.pick1.app.data.model.LiveScore>>(emptyList()); private set

    /** The user's own tracked stakes, by pick id. */
    var bets by mutableStateOf<Map<String, com.pick1.app.data.UserBet>>(emptyMap()); private set

    var loading by mutableStateOf(true); private set
    var error by mutableStateOf<String?>(null); private set
    var sport by mutableStateOf("all"); private set

    /**
     * Entitlement. Play Billing isn't wired yet, so the app runs in the FREE
     * tier — which is the surface we want to verify first.
     */
    var isPro by mutableStateOf(false); private set
    fun updateEntitlement(pro: Boolean) { isPro = pro }

    /**
     * The rail: ALL, then every one of the ten sports, always.
     *
     * The old list showed only sports present on today's board and was
     * missing football entirely, so on a light day the app looked like it
     * had lost half its coverage. Ten sports is the product's claim; a sport
     * with nothing on it reads quiet instead of vanishing.
     */
    val sports: List<String> get() = listOf(ALL_SPORTS) + P1_SPORTS

    fun hasPicks(s: String): Boolean =
        if (s == ALL_SPORTS) todayPicks.isNotEmpty() else todayPicks.any { it.sport == s }

    /**
     * The hero.
     *
     * Free sees the call with the BIGGEST RETURN, not the safest one: it is
     * the single pick they get, so it should be the one worth opening the app
     * for. Pro sees the highest-confidence call, which is what a full board
     * should lead with.
     */
    fun hero(isPro: Boolean): Pick? =
        if (isPro) filteredToday.maxByOrNull { it.probability }
        else filteredToday.maxByOrNull { it.decimalOdds }

    /** Everything else on the board, the hero removed by id. */
    fun rest(isPro: Boolean): List<Pick> {
        val h = hero(isPro)
        return filteredToday.filter { it.id != h?.id }
    }

    /** The free tier's single unlocked pick is the hero itself. */
    fun freeIds(isPro: Boolean): Set<String> =
        if (isPro) emptySet() else setOfNotNull(hero(false)?.id)

    /** Marks the call returning the most on the reference stake. */
    val biggestWinId: String? get() = filteredToday.maxByOrNull { it.decimalOdds }?.id

    /**
     * Games in play right now.
     *
     * Locked picks are NOT dropped: a free user still sees the game and the
     * score, and what is withheld is the call on it. A score is also only
     * trusted while it is fresh — rows can sit at InProgress for weeks after
     * a feed stops updating, and a frozen scoreboard is worse than none.
     */
    val liveNow: List<Pair<Pick, com.pick1.app.data.model.LiveScore>>
        get() {
            val live = liveScores.filter { it.isLive }
            return filteredToday.mapNotNull { p ->
                val gid = p.gameId ?: return@mapNotNull null
                live.firstOrNull { it.gameId == gid }?.let { p to it }
            }
        }

    /** Everything the user tracked or starred, newest first. */
    val yourPicks: List<Pick>
        get() = (todayPicks + history).distinctBy { it.id }.filter { it.id in bets.keys }

    val settled: List<Pick> get() = history.filter { !it.isPending }

    /** Net on a flat $100 a call over the settled window. */
    fun net(of: List<Pick>): Int = of.sumOf {
        if (it.isWin) (it.decimalOdds - 1) * 100 else -100.0
    }.roundToInt()

    val totalWins: Int get() = settled.count { it.isWin }
    val winRate: Int get() = if (settled.isEmpty()) 0 else (totalWins * 100) / settled.size

    /** Consecutive wins counting back from the most recent settled call. */
    val currentStreak: Int get() = settled.takeWhile { it.isWin }.size

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
                val live = runCatching { repo.liveScores() }.getOrDefault(emptyList())
                val mine = runCatching { com.pick1.app.data.BetRepository().load() }
                    .getOrDefault(emptyMap())
                listOf(today, hist, live, mine)
            }.onSuccess { parts ->
                @Suppress("UNCHECKED_CAST")
                todayPicks = parts[0] as List<Pick>
                @Suppress("UNCHECKED_CAST")
                history = parts[1] as List<Pick>
                @Suppress("UNCHECKED_CAST")
                liveScores = parts[2] as List<com.pick1.app.data.model.LiveScore>
                @Suppress("UNCHECKED_CAST")
                bets = parts[3] as Map<String, com.pick1.app.data.UserBet>
                error = null
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
    var showProfile by remember { mutableStateOf(false) }
    var tab by remember { mutableStateOf(P1V4Tab.TONIGHT) }
    var shareResult by remember { mutableStateOf<Pick?>(null) }

    // Live Play Billing entitlement + catalogue (falls back to placeholder
    // copy when Play is unavailable, e.g. an emulator without Play services).
    val ctx = LocalContext.current
    val activity = ctx as? Activity
    val isPro by Billing.isPro.collectAsState()
    val offers by Billing.offers.collectAsState()
    val trialEligible by Billing.trialEligible.collectAsState()

    // A completed purchase flips entitlement — drop the paywall automatically.
    LaunchedEffect(isPro) { if (isPro) showPaywall = false }

    selected?.let { p ->
        // Free tier sees the tease detail (matchup shown, call locked);
        // Pro sees the real breakdown. Same split as iOS.
        if (isPro) {
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
    shareResult?.let { p ->
        com.pick1.app.ui.share.ShareWinSheet(p, isPro) { shareResult = null }
        return
    }
    if (showProfile) {
        com.pick1.app.ui.profile.ProfileScreen()
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
            isPro = isPro,
            onClose = { showSummerFootball = false },
            onUnlock = { showSummerFootball = false; showPaywall = true },
            onTapPick = { selected = it },
        )
        return
    }
    if (showPaywall) {
        val plans = offers.ifEmpty { PlaceholderCatalogue.plans(trialEligible) }
        PaywallScreen(
            plans = plans,
            trialEligible = trialEligible,
            onBuy = { plan -> activity?.let { Billing.purchase(it, plan.productId) } },
            onRestore = { Billing.restore() },
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

            else -> {
                val hero = vm.hero(isPro)
                val rest = vm.rest(isPro)
                val freeIds = vm.freeIds(isPro)
                val biggest = vm.biggestWinId

                LazyColumn(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                    item { P1V4TopBar(onProfile = { showProfile = true }) }
                    item { P1V4Segment(tab) { tab = it } }

                    when (tab) {
                        P1V4Tab.TONIGHT -> {
                            item {
                                P1V4OrbRail(
                                    sports = vm.sports,
                                    active = vm.sport,
                                    hasPicks = vm::hasPicks,
                                    onSelect = { vm.select(it) },
                                )
                            }

                            if (hero != null) {
                                item { P1V4Hero(hero) { selected = hero } }
                            } else if (vm.sport != ALL_SPORTS && vm.todayPicks.isNotEmpty()) {
                                // Selected a sport with nothing on it. Say so
                                // plainly rather than dropping the user onto a
                                // blank screen that reads as a broken app.
                                item {
                                    P1V4EmptyState(
                                        "No ${v4Name(vm.sport).lowercase()} calls today",
                                        "The board carries every game the AI could call. This sport has none on today's slate.",
                                    )
                                }
                            }

                            item {
                                Row(
                                    verticalAlignment = Alignment.Bottom,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(start = 22.dp, end = 22.dp, top = 30.dp, bottom = 14.dp),
                                ) {
                                    Text(
                                        stringResource(R.string.rd_todays_games),
                                        style = anton(22),
                                        color = P1.Foreground,
                                        modifier = Modifier.weight(1f),
                                    )
                                    Text(
                                        "ALL CALLED BY 6 AM",
                                        style = mono(9, androidx.compose.ui.text.font.FontWeight.Bold),
                                        color = V4.mute,
                                    )
                                }
                            }

                            items(rest, key = { it.id }) { p ->
                                Box(Modifier.padding(horizontal = 22.dp, vertical = 6.dp)) {
                                    P1V4GameRow(
                                        pick = p,
                                        isLocked = !isPro && p.id !in freeIds,
                                        isBiggestWin = p.id == biggest,
                                        onTap = { selected = p },
                                        onTrack = { if (isPro) selected = p else showPaywall = true },
                                    )
                                }
                            }

                            if (!isPro) {
                                item {
                                    Box(Modifier.padding(top = 18.dp)) {
                                        P1V4PayBar(perDay = "$1.33", sports = P1_SPORTS.size) {
                                            showPaywall = true
                                        }
                                    }
                                }
                            }
                        }

                        P1V4Tab.LIVE -> {
                            val live = vm.liveNow
                            if (live.isEmpty()) {
                                item {
                                    P1V4EmptyState(
                                        "Nothing in play",
                                        "Games appear here the moment they kick off, with the score and the call side by side.",
                                    )
                                }
                            } else {
                                items(live, key = { it.first.id }) { (p, sc) ->
                                    P1V4LiveCard(
                                        pick = p,
                                        score = sc,
                                        tint = V4.glow(p.sport),
                                        isLocked = !isPro && p.id !in freeIds,
                                    )
                                }
                            }
                        }

                        P1V4Tab.YOURS -> {
                            val mine = vm.yourPicks
                            if (mine.isEmpty()) {
                                item {
                                    P1V4EmptyState(
                                        "You haven't tracked a call yet",
                                        "Track one from tonight's board and it lands here, with what it stands to return.",
                                    )
                                }
                            } else {
                                items(mine, key = { it.id }) { p ->
                                    P1V4YourRow(p, vm.bets[p.id]) { selected = p }
                                }
                            }
                        }

                        P1V4Tab.RESULTS -> {
                            val settled = vm.settled
                            item { P1V4MoneyStrip(vm.net(settled), settled.size) }
                            item {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 22.dp)
                                        .padding(top = 10.dp),
                                ) {
                                    P1V4ResultBox("${vm.totalWins}/${settled.size}", "Picks won")
                                    P1V4ResultBox("${vm.winRate}%", "Hit rate")
                                    P1V4ResultBox(
                                        "${vm.currentStreak}",
                                        "Win streak",
                                        flame = vm.currentStreak >= 2,
                                    )
                                }
                            }
                            if (settled.isEmpty()) {
                                item {
                                    P1V4EmptyState(
                                        "No settled calls yet",
                                        "Every pick is logged before kickoff and graded here once it lands.",
                                    )
                                }
                            } else {
                                itemsIndexed(settled.take(20), key = { _, p -> p.id }) { i, p ->
                                    P1V4ResultRow(
                                        pick = p,
                                        isHighlight = i == 0 && p.isWin,
                                        onShare = { shareResult = p },
                                    ) { selected = p }
                                }
                            }
                        }
                    }

                    item { Spacer(Modifier.height(120.dp)) }
                }
            }
        }
    }
}
