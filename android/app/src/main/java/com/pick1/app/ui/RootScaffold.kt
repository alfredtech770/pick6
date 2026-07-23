package com.pick1.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import androidx.compose.ui.platform.LocalContext
import com.pick1.app.BuildConfig
import com.pick1.app.data.Prefs
import com.pick1.app.ui.funnel.FunnelHost
import kotlinx.coroutines.launch
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.detail.MatchDetailScreen
import com.pick1.app.ui.home.HomeScreen
import com.pick1.app.ui.live.LiveScreen
import com.pick1.app.ui.wins.WinsScreen
import com.pick1.app.ui.history.PredictionHistoryScreen
import com.pick1.app.ui.profile.ProfileScreen
import com.pick1.app.ui.splash.SplashScreen
import com.pick1.app.ui.theme.*

/**
 * Root shell with the floating bottom-nav pill — the Android counterpart of
 * the iOS tab bar. HOME and PROFILE are live; PICKS and LIVE land with their
 * screen ports.
 */
private enum class RootTab { HOME, PICKS, LIVE, PROFILE }

@Composable
fun RootScaffold(forceSkipOnboarding: Boolean = false, debugScreen: String? = null) {
    var tab by remember { mutableStateOf(RootTab.HOME) }
    // First run shows the onboarding funnel, once — persisted in DataStore
    // exactly like the iOS `hasFinishedOnboarding` @AppStorage key.
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val onboarded by Prefs.onboarded(ctx).collectAsState(initial = null)

    when (if (forceSkipOnboarding) true else onboarded) {
        null -> return          // first frame: don't flash the wrong screen
        false -> {
            FunnelHost(onFinished = { scope.launch { Prefs.setOnboarded(ctx, true) } })
            return
        }
        else -> Unit
    }

    // Splash while the first load settles (port of Pick1SplashLoader).
    var splashDone by remember { mutableStateOf(false) }
    if (!splashDone && debugScreen == null) {
        SplashScreen(onDone = { splashDone = true })
        return
    }

    // DEBUG: jump straight to a screen for review.
    if (debugScreen == "summerFootball") {
        com.pick1.app.ui.summerfootball.SummerFootballScreen(
            isPro = false, onClose = { }, onUnlock = { }, onTapPick = { },
        )
        return
    }

    // Detail is shown over whichever tab opened it.
    var detail by remember { mutableStateOf<Pick?>(null) }
    detail?.let { p ->
        MatchDetailScreen(p) { detail = null }
        return
    }

    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        when (tab) {
            RootTab.HOME -> HomeScreen()
            RootTab.PICKS -> WinsScreen { detail = it }
            RootTab.LIVE -> LiveScreen { detail = it }
            RootTab.PROFILE -> ProfileScreen()
        }
        BottomNav(
            tab = tab,
            onSelect = { tab = it },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 26.dp),
        )
    }
}

@Composable
private fun BottomNav(tab: RootTab, onSelect: (RootTab) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF15171B))
            .border(1.dp, P1.Line, RoundedCornerShape(28.dp))
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        NavItem(Icons.Default.Home, stringResource(R.string.nav_home), tab == RootTab.HOME) {
            onSelect(RootTab.HOME)
        }
        NavItem(Icons.Default.BarChart, stringResource(R.string.nav_picks), tab == RootTab.PICKS) {
            onSelect(RootTab.PICKS)
        }
        NavItem(Icons.Default.Bolt, stringResource(R.string.nav_live), tab == RootTab.LIVE) {
            onSelect(RootTab.LIVE)
        }
        NavItem(Icons.Default.Person, stringResource(R.string.nav_profile), tab == RootTab.PROFILE) {
            onSelect(RootTab.PROFILE)
        }
    }
}

@Composable
private fun NavItem(icon: ImageVector, label: String, active: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .clip(RoundedCornerShape(22.dp))
            .background(if (active) P1.Lime else Color.Transparent)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Icon(
            icon,
            contentDescription = label,
            tint = if (active) P1.LimeInk else P1.Mute,
            modifier = Modifier.size(17.dp),
        )
        Text(
            label.uppercase(),
            style = archivoNarrow(10, FontWeight.Bold, tracking = 1.4f),
            color = if (active) P1.LimeInk else P1.Mute,
        )
    }
}
