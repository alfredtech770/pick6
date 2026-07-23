package com.pick1.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import com.pick1.app.ui.Sport
import com.pick1.app.ui.theme.P1
import com.pick1.app.ui.theme.archivoNarrow

/**
 * Circular team crest / athlete face — the Android counterpart of
 * `TeamLogo.swift`.
 *
 * The crest URL comes straight from `picks.home_logo` / `away_logo`, which
 * the server-side pipeline (`pipeline/images.js`) already resolved and
 * verified. That's why coverage is 100% for team sports with no client-side
 * lookup — the exact same win the iOS app got.
 *
 * When there's no image (individual sports whose athlete has no photo), we
 * fall back to initials on a tinted disc, matching the iOS placeholder.
 */
@Composable
fun TeamLogo(
    sport: String,
    team: String,
    logoUrl: String?,
    size: Int = 44,
    modifier: Modifier = Modifier,
) {
    val tint = Sport.tint(sport)
    Box(
        modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(P1.Panel2)
            .border(1.dp, tint.copy(alpha = 0.35f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (!logoUrl.isNullOrBlank()) {
            SubcomposeAsyncImage(
                model = logoUrl,
                contentDescription = team,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size((size * 0.72f).dp),
                error = { Initials(team, size) },
                loading = { Initials(team, size) },
            )
        } else {
            Initials(team, size)
        }
    }
}

@Composable
private fun Initials(team: String, size: Int) {
    val initials = team.split(" ")
        .filter { it.isNotBlank() }
        .take(2)
        .joinToString("") { it.first().uppercase() }
        .ifEmpty { "?" }
    Text(
        initials,
        style = archivoNarrow((size * 0.34f).toInt().coerceAtLeast(8), FontWeight.Bold, tracking = 0.5f),
        color = P1.Ink2,
    )
}
