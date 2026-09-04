package com.pick1.app.ui.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import androidx.compose.ui.platform.LocalContext
import com.pick1.app.data.Favorites
import com.pick1.app.data.model.Pick
import kotlinx.coroutines.launch
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

/**
 * Match detail — port of `MatchDetailView` (Pick1Screens.swift).
 *
 * Tabs mirror iOS exactly: OUR CALL · AI ANALYSIS · <sport-adaptive stats>.
 * (The old LINEUPS / H2H tabs were removed on iOS because they showed
 * fabricated rosters — deliberately not reintroduced here.)
 */
private enum class DetailTab { OUR_CALL, ANALYSIS, STATS }

@Composable
fun MatchDetailScreen(pick: Pick, onClose: () -> Unit) {
    var tab by remember { mutableStateOf(DetailTab.OUR_CALL) }
    val accent = Sport.accent(pick.sport)
    val scope = rememberCoroutineScope()
    var tracked by remember(pick.id) { mutableStateOf(false) }
    LaunchedEffect(pick.id) {
        tracked = runCatching { com.pick1.app.data.BetRepository().load().containsKey(pick.id) }
            .getOrDefault(false)
    }

    Box(Modifier.fillMaxSize()) {
    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding(),
    ) {
        TopBar(pick, onClose)
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
        ) {
            // The ticket leads the page, as on iOS: one call, logged before
            // kickoff, with its terms printed on it. The matchup header stays
            // underneath as context rather than as the subject.
            Spacer(Modifier.height(8.dp))
            com.pick1.app.ui.components.P1PickTicket(
                pick = pick,
                homeScore = pick.homeScore,
                awayScore = pick.awayScore,
                isLive = pick.isPending && pick.homeScore != null,
                confidence = com.pick1.app.ui.components.confidenceTierText(pick),
                loggedAt = pick.startTime ?: "PRE-GAME",
            )
            Spacer(Modifier.height(20.dp))
            MatchupHeader(pick, accent)
            Spacer(Modifier.height(16.dp))
            TabBar(pick, tab, accent) { tab = it }
            Spacer(Modifier.height(16.dp))
            when (tab) {
                DetailTab.OUR_CALL -> OurCallPanel(pick, accent)
                DetailTab.ANALYSIS -> AnalysisPanel(pick)
                DetailTab.STATS -> StatsPanel(pick)
            }
            // Clearance for the collapsed drawer pinned below.
            Spacer(Modifier.height(120.dp))
        }
    }

        // Tracking lives here, as on iOS: the collapsed bar is always
        // present on a pick you can act on, and drags up into stake entry.
        if (pick.isPending) {
            com.pick1.app.ui.tracker.P1BetDrawer(
                pick = pick,
                accent = accent,
                isTracked = tracked,
                onTrack = { stake ->
                    scope.launch {
                        com.pick1.app.data.BetRepository().track(pick, stake)
                        tracked = true
                    }
                },
                onDismiss = {},
            )
        }
    }
}

@Composable
private fun TopBar(pick: Pick, onClose: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = stringResource(R.string.action_back),
            tint = P1.Foreground,
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(P1.Panel)
                .clickable { onClose() }
                .padding(9.dp),
        )
        Spacer(Modifier.weight(1f))
        Text(
            "${Sport.emoji(pick.sport)} ${pick.league.uppercase()}",
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
            color = P1.Mute,
        )
        Spacer(Modifier.weight(1f))
        // Star -> favorites, which is what populates the PICKS tab.
        val ctx = LocalContext.current
        val scope = rememberCoroutineScope()
        val favIds by Favorites.ids(ctx).collectAsState(initial = emptySet())
        val starred = pick.id in favIds
        Icon(
            if (starred) Icons.Default.Star else Icons.Default.StarBorder,
            contentDescription = null,
            tint = if (starred) P1.Lime else P1.Mute,
            modifier = Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(P1.Panel)
                .clickable { scope.launch { Favorites.toggle(ctx, pick.id) } }
                .padding(9.dp),
        )
    }
}

/** Crest pair + "AWAY VS HOME", or the single competitor for field events. */
@Composable
private fun MatchupHeader(pick: Pick, accent: Color) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(P1.Panel)
            .border(1.dp, P1.Line, RoundedCornerShape(18.dp))
            .padding(vertical = 20.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (pick.isFieldEvent) {
            TeamLogo(pick.sport, pick.pick, null, size = 72)
            Spacer(Modifier.height(10.dp))
            Text(pick.pick.uppercase(), style = anton(22), color = P1.Foreground)
            Text(
                pick.homeTeam.uppercase(),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.4f),
                color = P1.Mute,
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 60)
                Text(
                    stringResource(R.string.card_vs),
                    style = anton(16),
                    color = accent.copy(alpha = 0.8f),
                )
                TeamLogo(pick.sport, pick.homeTeam, pick.homeLogo, size = 60)
            }
            Spacer(Modifier.height(12.dp))
            Text(
                "${Sport.short(pick.awayTeam)} — ${Sport.short(pick.homeTeam)}",
                style = anton(18),
                color = P1.Foreground,
            )
        }
        if (pick.homeScore != null && pick.awayScore != null) {
            Spacer(Modifier.height(6.dp))
            Text(
                "${pick.awayScore} – ${pick.homeScore}",
                style = anton(20),
                color = if (pick.isWin) P1.WinLime else P1.Ink2,
            )
        }
    }
}

@Composable
private fun TabBar(pick: Pick, selected: DetailTab, accent: Color, onSelect: (DetailTab) -> Unit) {
    val statsLabel = when (pick.sport) {
        "combat" -> stringResource(R.string.rd_fighters)
        "f1", "golf" -> stringResource(R.string.rd_field)
        "tennis" -> stringResource(R.string.rd_players)
        else -> stringResource(R.string.rd_team_stats)
    }
    val tabs = listOf(
        DetailTab.OUR_CALL to stringResource(R.string.rd_our_call),
        DetailTab.ANALYSIS to stringResource(R.string.rd_ai_analysis),
        DetailTab.STATS to statsLabel,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        tabs.forEach { (t, label) ->
            val active = t == selected
            Text(
                label,
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.4f),
                color = if (active) P1.LimeInk else P1.Ink2,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(if (active) accent else P1.Panel)
                    .border(1.dp, if (active) Color.Transparent else P1.Line, RoundedCornerShape(20.dp))
                    .clickable { onSelect(t) }
                    .padding(horizontal = 12.dp, vertical = 9.dp),
            )
        }
    }
}

/**
 * OUR CALL — who we back, our % vs the market's implied %, and the value
 * verdict. Mirrors `ourCallPanel`, including the deliberate
 * "not a guarantee / not financial advice" framing.
 */
@Composable
private fun OurCallPanel(pick: Pick, accent: Color) {
    val ourPct = pick.probability.roundToInt()
    val impliedPct = pick.impliedProbability?.roundToInt()

    Column(Modifier.fillMaxWidth()) {
        Text(
            stringResource(R.string.rd_were_backing),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.4f),
            color = P1.Mute,
        )
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                pick.pick.uppercase(),
                style = anton(22),
                color = P1.Foreground,
                modifier = Modifier.weight(1f),
            )
            Text("$ourPct%", style = anton(22), color = accent)
        }
        Spacer(Modifier.height(14.dp))

        if (impliedPct != null) {
            HDivider()
            Row(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(R.string.rd_our_read),
                        style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                        color = P1.Mute,
                    )
                    Text("$ourPct%", style = anton(20), color = P1.Foreground)
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                    Text(
                        stringResource(R.string.rd_market_implied),
                        style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                        color = P1.Mute,
                    )
                    Text("$impliedPct%", style = anton(20), color = P1.Ink2)
                }
            }
            HDivider()
            Spacer(Modifier.height(12.dp))
            ValueVerdict(edge = ourPct - impliedPct, accent = accent)
        } else {
            HDivider()
            Text(
                stringResource(R.string.rd_no_market_line),
                style = archivo(12),
                color = Color(0xFF8A8D94),
                modifier = Modifier.padding(vertical = 12.dp),
            )
        }

        // More predictions (betting props)
        pick.bettingProps?.takeIf { it.isNotEmpty() }?.let { props ->
            Spacer(Modifier.height(18.dp))
            Text(
                "${stringResource(R.string.rd_more_predictions)} · ${props.size}",
                style = archivoNarrow(9, FontWeight.Bold, tracking = 2.0f),
                color = P1.Mute,
            )
            Spacer(Modifier.height(8.dp))
            props.forEach { p ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(p.label, style = archivo(12, FontWeight.SemiBold), color = P1.Ink2)
                        p.hint?.let {
                            Text(it, style = archivo(10), color = P1.Mute)
                        }
                    }
                    Text(p.value, style = anton(15), color = P1.Foreground)
                }
                HDivider()
            }
        }

        Spacer(Modifier.height(16.dp))
        Text(
            stringResource(R.string.rd_ai_projection_disc),
            style = archivoNarrow(9, FontWeight.Bold, tracking = 1.2f),
            color = P1.Mute,
        )
    }
}

/** VALUE / FAIR PRICE / NO EDGE verdict — thresholds match iOS (±6). */
@Composable
private fun ValueVerdict(edge: Int, accent: Color) {
    val isValue = edge >= 6
    val isNoEdge = edge <= -6
    val label = when {
        isValue -> "${stringResource(R.string.rd_value_label)} · +$edge%"
        isNoEdge -> "${stringResource(R.string.rd_no_edge)} · $edge%"
        else -> stringResource(R.string.rd_fair_price)
    }
    val sub = when {
        isValue -> stringResource(R.string.rd_value_sub)
        isNoEdge -> stringResource(R.string.rd_no_edge_sub)
        else -> stringResource(R.string.rd_fair_price_body)
    }
    val fg = when {
        isValue -> Color(0xFF0A0B0D)
        isNoEdge -> Color(0xFFF0A8A0)
        else -> Color(0xFFE7E4DC)
    }
    val bg = when {
        isValue -> accent
        isNoEdge -> Color(0xFF2A1416)
        else -> Color(0xFF16181C)
    }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, style = archivoNarrow(12, FontWeight.Bold, tracking = 1.4f), color = fg)
        Text(
            sub,
            style = archivo(11),
            color = if (isValue) Color(0xFF0A0B0D).copy(alpha = 0.7f) else Color(0xFF8A8D94),
        )
    }
}

/** AI ANALYSIS — the model's reasoning + key factor. */
@Composable
private fun AnalysisPanel(pick: Pick) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        pick.keyFactor?.takeIf { it.isNotBlank() }?.let {
            Column {
                Text(
                    stringResource(R.string.rd_why_ai_likes),
                    style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
                    color = P1.Mute,
                )
                Spacer(Modifier.height(6.dp))
                Text(it, style = anton(16), color = P1.Foreground)
            }
        }
        Text(pick.reasoning, style = archivo(13), color = P1.Ink2)
    }
}

/** Sport-adaptive stats: matchup facts (all sports) + field odds (race events). */
@Composable
private fun StatsPanel(pick: Pick) {
    Column(Modifier.fillMaxWidth()) {
        pick.matchupFacts?.takeIf { it.isNotEmpty() }?.forEach { f ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(f.label, style = archivo(12), color = P1.Mute, modifier = Modifier.weight(1f))
                Text(
                    f.value,
                    style = archivo(12, FontWeight.SemiBold),
                    color = P1.Foreground,
                    modifier = Modifier.weight(1.4f),
                )
            }
            HDivider()
        }

        pick.fieldOdds?.takeIf { it.isNotEmpty() }?.let { odds ->
            Spacer(Modifier.height(14.dp))
            Text(
                stringResource(R.string.rd_podium_probs),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
                color = P1.Mute,
            )
            Spacer(Modifier.height(8.dp))
            odds.forEach { d ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(d.name, style = archivo(12), color = P1.Ink2, modifier = Modifier.weight(1f))
                    d.win?.let {
                        Text("${it.roundToInt()}%", style = anton(15), color = P1.Lime)
                    }
                    d.podium?.let {
                        Spacer(Modifier.width(10.dp))
                        Text(
                            "${stringResource(R.string.rd_podium_word)} ${it.roundToInt()}%",
                            style = mono(9, FontWeight.Bold),
                            color = P1.Mute,
                        )
                    }
                }
                HDivider()
            }
        }
    }
}

@Composable
private fun HDivider() {
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(P1.Line),
    )
}
