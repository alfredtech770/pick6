package com.pick1.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.ui.theme.*

/**
 * The big two-tone page title used by the Live / Wins / Picks tabs —
 * port of `PageHero` (Pick1Screens.swift). A radial glow bleeds behind the
 * text rather than claiming layout height, exactly as on iOS.
 */
@Composable
fun PageHero(
    title: String,
    titleAccent: String,
    sub: List<String>,
    glow: Color,
    modifier: Modifier = Modifier,
) {
    Box(modifier.fillMaxWidth()) {
        Box(
            Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        listOf(glow.copy(alpha = 0.18f), Color.Transparent),
                        center = Offset(180f, 60f),
                        radius = 700f,
                    )
                )
        )
        Column(
            Modifier.padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Spacer(Modifier.height(6.dp))
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(title, style = anton(56, tracking = -0.7f), color = P1.Foreground)
                Text(titleAccent, style = anton(56, tracking = -0.7f), color = P1.Lime)
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                sub.forEachIndexed { i, item ->
                    if (i > 0) {
                        Box(
                            Modifier
                                .size(4.dp)
                                .clip(CircleShape)
                                .background(P1.Mute),
                        )
                    }
                    Text(
                        item,
                        style = archivoNarrow(11, FontWeight.Bold, tracking = 2.4f),
                        color = P1.Mute,
                    )
                }
            }
        }
    }
}

/** Breadcrumb strip above a PageHero — the iOS `TopNavBar` crumb. */
@Composable
fun TopCrumb(crumb: String, accent: String, live: Boolean = false) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            crumb,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
            color = P1.Mute,
        )
        Text(
            accent,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
            color = if (live) P1.Hot else P1.Lime,
        )
        if (live) {
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(6.dp).clip(CircleShape).background(P1.Hot))
        }
    }
}
