package com.pick1.app.ui.splash

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.delay

/**
 * Splash / loader — port of `Pick1SplashLoader.swift`.
 *
 * EST · 2026  /  PICK1 wordmark  /  PICKS · STATS · GLORY, with the
 * "LOADING PICKS…" caption pulsing underneath while the first fetch runs.
 */
@Composable
fun SplashScreen(onDone: () -> Unit = {}, minDurationMs: Long = 1200) {
    LaunchedEffect(Unit) {
        delay(minDurationMs)
        onDone()
    }

    val pulse = rememberInfiniteTransition(label = "pulse")
    val alpha by pulse.animateFloat(
        initialValue = 0.35f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "alpha",
    )

    Column(
        Modifier.fillMaxSize().background(P1.Ink),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "EST · 2026",
            style = archivoNarrow(10, FontWeight.Bold, tracking = 3.0f),
            color = P1.Mute,
        )
        Spacer(Modifier.height(18.dp))
        // The wordmark: PICK + a lime tile carrying the 1.
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("PICK", style = anton(64, tracking = -0.6f), color = P1.Foreground)
            Box(
                Modifier
                    .padding(start = 4.dp)
                    .size(58.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(P1.Lime),
                contentAlignment = Alignment.Center,
            ) {
                Text("1", style = anton(46), color = P1.LimeInk)
            }
        }
        Spacer(Modifier.height(18.dp))
        Text(
            stringResource(R.string.rd_picks_stats_glory),
            style = archivoNarrow(11, FontWeight.Bold, tracking = 2.6f),
            color = P1.Mute,
        )
        Spacer(Modifier.height(46.dp))
        Text(
            stringResource(R.string.rd_loading_picks),
            style = mono(10, FontWeight.Medium, tracking = 1.6f),
            color = P1.Mute,
            modifier = Modifier.alpha(alpha),
        )
    }
}
