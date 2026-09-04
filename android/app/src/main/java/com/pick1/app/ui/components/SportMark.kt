package com.pick1.app.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.SportsBaseball
import androidx.compose.material.icons.filled.SportsBasketball
import androidx.compose.material.icons.filled.SportsCricket
import androidx.compose.material.icons.filled.SportsFootball
import androidx.compose.material.icons.filled.SportsGolf
import androidx.compose.material.icons.filled.SportsHockey
import androidx.compose.material.icons.filled.SportsMma
import androidx.compose.material.icons.filled.SportsMotorsports
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material.icons.filled.SportsTennis
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.pick1.app.ui.home.ALL_SPORTS
import com.pick1.app.ui.home.V4

/**
 * The sport vocabulary, the Android half of iOS's `P1SportMark`.
 *
 * iOS replaced emoji with SF Symbols on 2026-08-31. Android had no equivalent
 * glyph set, or so it looked: Material Icons Extended is already a dependency
 * and carries a mark for all ten sports, cricket, motorsport and golf
 * included. So the emoji are gone here too, and both platforms draw a tinted
 * vector rather than a colour picture whose look is decided by the OS font.
 *
 * Off-state marks desaturate rather than dim, so the selected sport is the
 * only colour in a row.
 */
fun sportIcon(sport: String): ImageVector = when (sport) {
    ALL_SPORTS -> Icons.Filled.GridView
    "basketball" -> Icons.Filled.SportsBasketball
    "football" -> Icons.Filled.SportsFootball
    "soccer" -> Icons.Filled.SportsSoccer
    "hockey" -> Icons.Filled.SportsHockey
    "baseball" -> Icons.Filled.SportsBaseball
    "combat" -> Icons.Filled.SportsMma
    "f1" -> Icons.Filled.SportsMotorsports
    "tennis" -> Icons.Filled.SportsTennis
    "cricket" -> Icons.Filled.SportsCricket
    "golf" -> Icons.Filled.SportsGolf
    else -> Icons.Filled.GridView
}

@Composable
fun P1SportMark(
    sport: String,
    size: Int = 19,
    active: Boolean = true,
    modifier: Modifier = Modifier,
) {
    // ALL is not a sport, so off it goes neutral grey rather than a dimmer
    // lime, which read as a second selected chip. A sport off desaturates
    // instead, so the selected one is the only real colour in the row.
    val tint = when {
        sport == ALL_SPORTS && active -> Color(0xFFD4FF3A)
        sport == ALL_SPORTS -> V4.ink2
        active -> V4.glow(sport)
        else -> V4.glow(sport).copy(alpha = 0.55f)
    }
    Icon(
        imageVector = sportIcon(sport),
        contentDescription = null,
        tint = tint,
        modifier = modifier.size(size.dp),
    )
}
