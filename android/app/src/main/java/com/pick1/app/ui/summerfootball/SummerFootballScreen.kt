package com.pick1.app.ui.summerfootball

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
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
import com.pick1.app.ui.theme.WC
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * Summer Football hub — port of `SummerFootballHubView`
 * (Pick1SummerFootball.swift).
 *
 * Its own gold/navy identity rather than the app's lime: gold banner, gold
 * accents, gold lock states. Free tier sees the featured match and a locked
 * slate card; Pro sees the full list.
 *
 * NOTE the copy deliberately says "Summer Football", never the FIFA
 * trademark — the app took a 5.2.1 rejection over that on iOS.
 */
class SummerFootballViewModel : ViewModel() {
    private val repo = PicksRepository()
    var matches by mutableStateOf<List<Pick>>(emptyList()); private set
    var loading by mutableStateOf(true); private set

    init {
        viewModelScope.launch {
            runCatching { repo.todayPicks() + repo.latestWins(limit = 60) }
                .onSuccess { all ->
                    matches = all
                        .distinctBy { it.id }
                        .filter { it.league == "WC" && it.isPending }
                        .sortedWith(compareBy({ it.gameDate }, { -it.probability }))
                }
            loading = false
        }
    }

    val featured: Pick? get() = matches.firstOrNull()
    val slate: List<Pick> get() = matches.drop(1).take(11)
}

@Composable
fun SummerFootballScreen(
    vm: SummerFootballViewModel = viewModel(),
    isPro: Boolean = false,
    onClose: () -> Unit,
    onUnlock: () -> Unit,
    onTapPick: (Pick) -> Unit,
) {
    LazyColumn(Modifier.fillMaxSize().background(WC.Bg)) {
        item {
            Column(Modifier.safeDrawingPadding().padding(horizontal = 16.dp)) {
                Spacer(Modifier.height(8.dp))
                TopNav(onClose)
                Spacer(Modifier.height(14.dp))
                HeroBanner()
                Spacer(Modifier.height(18.dp))
            }
        }

        vm.featured?.let { feat ->
            item {
                SectionHead(
                    title = "NEXT", accent = "MATCH",
                    meta = feat.startTime ?: feat.gameDate, live = true,
                )
                Box(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                    FeaturedMatch(feat) { onTapPick(feat) }
                }
                Spacer(Modifier.height(12.dp))
            }
        }

        if (vm.slate.isNotEmpty()) {
            item {
                SectionHead(
                    title = "UPCOMING", accent = "MATCHES",
                    meta = "${vm.slate.size} MORE", live = false,
                )
            }
            if (isPro) {
                items(vm.slate, key = { it.id }) { p ->
                    Box(Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) {
                        MatchRow(p) { onTapPick(p) }
                    }
                }
            } else {
                // Free tier: the full slate is locked; one tap opens the paywall.
                item {
                    Box(Modifier.padding(horizontal = 16.dp)) { SlateLockCard(onUnlock) }
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }

        if (!vm.loading && vm.matches.isEmpty()) {
            item {
                Box(Modifier.padding(horizontal = 16.dp)) { EmptySlate() }
            }
        }
        item { Spacer(Modifier.height(140.dp)) }
    }
}

@Composable
private fun TopNav(onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Icon(
            Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = stringResource(R.string.action_back),
            tint = WC.Ink,
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(WC.Panel)
                .border(1.dp, WC.Line, RoundedCornerShape(12.dp))
                .clickable { onClose() }
                .padding(9.dp),
        )
        Spacer(Modifier.weight(1f))
        Row(
            Modifier
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(
                        listOf(WC.Navy, WC.Blue),
                        start = Offset.Zero, end = Offset.Infinite,
                    )
                )
                .border(1.dp, WC.Gold, CircleShape)
                .padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("🏆", style = archivo(10))
            Text(
                stringResource(R.string.rd_sf_title),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
                color = WC.Gold,
            )
        }
        Spacer(Modifier.weight(1f))
        Spacer(Modifier.size(38.dp))
    }
}

/** The gold/navy `.wc-banner` hero. */
@Composable
private fun HeroBanner() {
    val everyMatch = stringResource(R.string.rd_sf_every_match_nl)
    val call = stringResource(R.string.rd_sf_call)
    val aiBy = stringResource(R.string.rd_sf_ai_by)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.linearGradient(
                    listOf(WC.Blue, WC.Navy, Color(0xFF05102A)),
                    start = Offset.Zero, end = Offset(900f, 700f),
                )
            )
            .border(1.dp, WC.Gold.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
            .padding(18.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("🏆", style = archivo(20))
            Spacer(Modifier.width(8.dp))
            Column {
                Text(
                    stringResource(R.string.rd_sf_summer_football),
                    style = anton(8, tracking = 2.6f),
                    color = WC.Gold,
                )
                Row {
                    Text("2026 ", style = anton(14), color = Color.White)
                    Text("USA · CAN · MEX", style = anton(14), color = WC.Gold)
                }
            }
            Spacer(Modifier.weight(1f))
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = Color.White.copy(alpha = 0.6f))) { append(aiBy) }
                    withStyle(SpanStyle(color = WC.Accent)) { append("PICK1") }
                },
                style = mono(8, FontWeight.Bold, tracking = 1.8f),
            )
        }
        Spacer(Modifier.height(14.dp))
        Text(
            buildAnnotatedString {
                withStyle(SpanStyle(color = Color.White)) { append(everyMatch) }
                withStyle(SpanStyle(color = WC.Gold)) { append(call) }
            },
            style = anton(44, tracking = -1.0f),
        )
        Spacer(Modifier.height(10.dp))
        Text(
            stringResource(R.string.rd_sf_group_stage),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
            color = Color.White.copy(alpha = 0.85f),
        )
    }
}

@Composable
private fun SectionHead(title: String, accent: String, meta: String, live: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = anton(20), color = WC.Ink)
        Spacer(Modifier.width(6.dp))
        Text(accent, style = anton(20), color = WC.Gold)
        Spacer(Modifier.weight(1f))
        if (live) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(P1.Hot))
            Spacer(Modifier.width(5.dp))
        }
        Text(
            meta,
            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.6f),
            color = WC.Mute,
        )
    }
}

/** The featured next match — gold-bordered, with our call and confidence. */
@Composable
private fun FeaturedMatch(pick: Pick, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(WC.Panel)
            .border(1.dp, WC.Gold.copy(alpha = 0.55f), RoundedCornerShape(18.dp))
            .clickable { onClick() }
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TeamColumn(pick.sport, pick.awayTeam, pick.awayLogo)
            Text(
                stringResource(R.string.card_vs),
                style = anton(16),
                color = WC.Gold.copy(alpha = 0.8f),
            )
            TeamColumn(pick.sport, pick.homeTeam, pick.homeLogo)
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(WC.Line))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    stringResource(R.string.rd_ai_picks),
                    style = archivoNarrow(9, FontWeight.Bold, tracking = 1.6f),
                    color = WC.Mute,
                )
                Text(
                    pick.pick.uppercase(),
                    style = anton(18),
                    color = WC.Gold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    "${pick.probability.roundToInt()}%",
                    style = anton(26),
                    color = WC.Accent,
                )
                Text(
                    stringResource(R.string.rd_confidence_label),
                    style = archivoNarrow(8, FontWeight.Bold, tracking = 2.0f),
                    color = Color.White.copy(alpha = 0.55f),
                )
            }
        }
    }
}

@Composable
private fun TeamColumn(sport: String, team: String, logo: String?) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.width(110.dp),
    ) {
        TeamLogo(sport, team, logo, size = 52)
        Text(
            Sport.short(team).uppercase(),
            style = anton(13),
            color = WC.Ink,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** A compact upcoming-match row (Pro only). */
@Composable
private fun MatchRow(pick: Pick, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(WC.Panel)
            .border(1.dp, WC.Line, RoundedCornerShape(14.dp))
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 34)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                "${Sport.short(pick.awayTeam)}  ${stringResource(R.string.card_vs)}  ${Sport.short(pick.homeTeam)}",
                style = anton(15),
                color = WC.Ink,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                pick.pick.uppercase(),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.2f),
                color = WC.Gold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text("${pick.probability.roundToInt()}%", style = anton(18), color = WC.Accent)
    }
}

/** Free tier: the whole slate behind one gold lock card. */
@Composable
private fun SlateLockCard(onUnlock: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(WC.Gold.copy(alpha = 0.06f))
            .border(1.dp, WC.Gold.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .clickable { onUnlock() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Default.Lock, null, tint = WC.Gold, modifier = Modifier.size(18.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                stringResource(R.string.rd_full_slate),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.8f),
                color = WC.Ink,
            )
            Text(
                stringResource(R.string.rd_sf_unlock_pro),
                style = archivo(11),
                color = WC.Mute,
            )
        }
        Text(
            stringResource(R.string.paywall_kicker),
            style = archivoNarrow(11, FontWeight.Bold, tracking = 1.6f),
            color = WC.Bg,
            modifier = Modifier
                .clip(CircleShape)
                .background(WC.Gold)
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

/** Between tournament days: everything played, next slate not dropped yet. */
@Composable
private fun EmptySlate() {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(WC.Panel)
            .border(1.dp, WC.Line, RoundedCornerShape(12.dp))
            .padding(vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Default.HourglassEmpty, null, tint = WC.Gold, modifier = Modifier.size(26.dp))
        Text(
            stringResource(R.string.rd_sf_next_fixtures),
            style = archivoNarrow(12, FontWeight.Bold, tracking = 2.2f),
            color = WC.Ink,
        )
        Text(
            stringResource(R.string.rd_sf_predictions_land),
            style = archivo(11),
            color = WC.Mute,
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * Home-feed entry point into the hub — the gold `.wc-banner` strip
 * (`SummerFootballBanner` on iOS). Only shown when WC fixtures exist.
 */
@Composable
fun SummerFootballBanner(onOpen: () -> Unit) {
    Row(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.linearGradient(
                    listOf(WC.Blue, WC.Navy),
                    start = Offset.Zero, end = Offset(700f, 400f),
                )
            )
            .border(1.dp, WC.Gold.copy(alpha = 0.55f), RoundedCornerShape(18.dp))
            .clickable { onOpen() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("🏆", style = archivo(22))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                stringResource(R.string.rd_sf_title),
                style = archivoNarrow(9, FontWeight.Bold, tracking = 2.4f),
                color = WC.Gold,
            )
            Text(
                stringResource(R.string.rd_sf_group_stage),
                style = archivo(12, FontWeight.Medium),
                color = Color.White.copy(alpha = 0.85f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text("→", style = anton(18), color = WC.Gold)
    }
}
