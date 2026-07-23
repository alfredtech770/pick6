package com.pick1.app.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.Sport
import com.pick1.app.ui.theme.*

/**
 * The home screen's sport filter — port of `SportDropdown`
 * (Pick1HomeHiFi.swift).
 *
 * This REPLACED the old horizontal chip carousel on iOS: a single capsule
 * button in the hero's top-right whose chevron flips open a menu of every
 * sport with its pick count, cascading in from the top-right.
 */
@Composable
fun SportDropdown(
    sports: List<String>,            // excludes "all"
    selected: String,
    countFor: (String) -> Int,
    isOpen: Boolean,
    onToggle: () -> Unit,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val chevron by animateFloatAsState(if (isOpen) -180f else 0f, label = "chevron")

    Column(modifier, horizontalAlignment = Alignment.End) {
        // ── Collapsed button ─────────────────────────────────────────
        Row(
            Modifier
                .clip(CircleShape)
                .background(Color(0xFF0A0B0D).copy(alpha = 0.85f))
                .border(
                    1.2.dp,
                    if (isOpen) P1.Lime.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.14f),
                    CircleShape,
                )
                .clickable { onToggle() }
                .padding(horizontal = 13.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            Text(
                if (selected == "all") "◎" else Sport.emoji(selected),
                style = archivo(12),
            )
            Text(
                (if (selected == "all") stringResource(R.string.rd_all_sports) else sportLabel(selected))
                    .uppercase(),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 1.8f),
                color = Color.White,
                maxLines = 1,
            )
            Icon(
                Icons.Default.KeyboardArrowDown,
                contentDescription = null,
                tint = P1.Lime,
                modifier = Modifier.size(14.dp).rotate(chevron),
            )
        }

        // ── Expanded menu ────────────────────────────────────────────
        AnimatedVisibility(
            visible = isOpen,
            enter = fadeIn() + expandVertically(spring(dampingRatio = 0.8f)),
            exit = fadeOut() + shrinkVertically(),
        ) {
            Column(
                Modifier
                    .padding(top = 10.dp)
                    .width(218.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color(0xFF101216))
                    .border(1.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(20.dp))
                    .padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                DropRow("all", stringResource(R.string.rd_all_sports), "◎",
                    countFor("all"), selected == "all") { onSelect("all") }
                sports.forEach { s ->
                    DropRow(s, sportLabel(s), Sport.emoji(s), countFor(s), selected == s) {
                        onSelect(s)
                    }
                }
            }
        }
    }
}

@Composable
private fun DropRow(
    key: String,
    label: String,
    emoji: String,
    count: Int,
    active: Boolean,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(13.dp))
            .background(if (active) P1.Lime.copy(alpha = 0.12f) else Color.Transparent)
            .clickable { onClick() }
            .padding(horizontal = 10.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .size(26.dp)
                .clip(CircleShape)
                .background(if (active) P1.Lime else Color.White.copy(alpha = 0.06f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(emoji, style = archivo(12))
        }
        Text(
            label,
            style = archivo(14, if (active) FontWeight.Bold else FontWeight.Medium),
            color = if (active) Color.White else Color(0xFFC9CBCF),
        )
        Spacer(Modifier.weight(1f))
        Text(
            "$count",
            style = mono(11, FontWeight.Bold),
            color = when {
                count == 0 -> Color(0xFF3A3D44)
                active -> P1.Lime
                else -> P1.Mute
            },
        )
        if (active) {
            Icon(Icons.Default.Check, null, tint = P1.Lime, modifier = Modifier.size(11.dp))
        }
    }
}

/** Display names matching the iOS dropdown labels. */
fun sportLabel(sport: String): String = when (sport) {
    "baseball" -> "MLB"
    "f1" -> "F1"
    "combat" -> "MMA"
    "soccer" -> "Soccer"
    "golf" -> "Golf"
    "cricket" -> "Cricket"
    "basketball" -> "Basketball"
    "hockey" -> "Hockey"
    "tennis" -> "Tennis"
    else -> sport.replaceFirstChar { it.uppercase() }
}
