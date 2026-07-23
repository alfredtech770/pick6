package com.pick1.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
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
import com.pick1.app.ui.home.HomeScreen
import com.pick1.app.ui.profile.ProfileScreen
import com.pick1.app.ui.theme.*

/**
 * Root shell with the floating bottom-nav pill — the Android counterpart of
 * the iOS tab bar. HOME and PROFILE are live; PICKS and LIVE land with their
 * screen ports.
 */
private enum class RootTab { HOME, PROFILE }

@Composable
fun RootScaffold() {
    var tab by remember { mutableStateOf(RootTab.HOME) }

    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        when (tab) {
            RootTab.HOME -> HomeScreen()
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
            .padding(horizontal = 18.dp, vertical = 10.dp),
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
