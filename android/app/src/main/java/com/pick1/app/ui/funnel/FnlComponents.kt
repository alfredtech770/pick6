package com.pick1.app.ui.funnel

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.ui.theme.*

/**
 * Funnel design system — port of the `Fnl*` atoms in
 * `Pick1OnboardingFunnel.swift`. Every one of the 20 screens is assembled
 * from these, so they match iOS exactly: same sizes, tracking and tones.
 */

/** Accent tone for the kicker / glow / headline emphasis. */
enum class Tone { LIME, RED, WIN }

fun Tone.color(): Color = when (this) {
    Tone.LIME -> P1.LimeFunnel
    Tone.RED -> P1.Hot
    Tone.WIN -> P1.Win
}

/** Top radial glow behind each screen. */
@Composable
fun FnlGlow(tone: Tone = Tone.LIME, modifier: Modifier = Modifier) {
    val c = tone.color()
    Box(
        modifier
            .fillMaxWidth()
            .height(320.dp)
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        c.copy(alpha = if (tone == Tone.LIME) 0.16f else 0.21f),
                        Color.Transparent,
                    ),
                    center = Offset(540f, 0f),
                    radius = 900f,
                )
            )
    )
}

/** Small caps kicker above the headline. */
@Composable
fun FnlKick(text: String, tone: Tone = Tone.LIME, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        style = archivoNarrow(12, FontWeight.Bold, tracking = 2.9f),
        color = tone.color(),
        modifier = modifier,
    )
}

/** Body copy under a headline. */
@Composable
fun FnlLead(text: String, modifier: Modifier = Modifier) {
    Text(text, style = archivo(16), color = P1.Ink2, modifier = modifier)
}

enum class CtaStyle { LIME, GHOST, DARK }

/** Primary call to action. */
@Composable
fun FnlCTA(
    title: String,
    style: CtaStyle = CtaStyle.LIME,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val bg = when (style) {
        CtaStyle.LIME -> P1.LimeFunnel
        CtaStyle.DARK -> P1.Panel2
        CtaStyle.GHOST -> Color.Transparent
    }
    val fg = when (style) {
        CtaStyle.LIME -> P1.Ink
        CtaStyle.DARK -> P1.Foreground
        CtaStyle.GHOST -> P1.Ink2
    }
    Text(
        title,
        style = anton(if (style == CtaStyle.GHOST) 16 else 20, tracking = 0.4f),
        color = fg,
        textAlign = TextAlign.Center,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .then(
                if (style == CtaStyle.GHOST) Modifier.border(1.dp, P1.Line, RoundedCornerShape(16.dp))
                else Modifier
            )
            .clickable { onClick() }
            .padding(vertical = if (style == CtaStyle.GHOST) 16.dp else 19.dp),
    )
}

/** The P1 tile + PICK1 wordmark lockup. */
@Composable
fun FnlLockup(modifier: Modifier = Modifier) {
    Row(
        modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(46.dp)
                .clip(RoundedCornerShape(13.dp))
                .background(P1.LimeFunnel),
            contentAlignment = Alignment.Center,
        ) {
            Text("P1", style = anton(24), color = P1.Ink)
        }
        Row {
            Text("PICK", style = anton(28), color = P1.Foreground)
            Text("1", style = anton(28), color = P1.LimeFunnel)
        }
    }
}

/** Thin progress bar shown on every step that has chrome. */
@Composable
fun FnlProgress(progress: Float, modifier: Modifier = Modifier) {
    // Springs to its new width instead of snapping. A bar that jumps reads
    // as a redraw; one that travels reads as progress.
    val width by androidx.compose.animation.core.animateFloatAsState(
        progress.coerceIn(0f, 1f),
        androidx.compose.animation.core.spring(dampingRatio = 0.8f),
        label = "progress",
    )
    Box(
        modifier
            .fillMaxWidth()
            .height(3.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(P1.Line),
    ) {
        Box(
            Modifier
                .fillMaxWidth(width)
                .height(3.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(P1.LimeFunnel),
        )
    }
}

/**
 * Screen shell: optional glow, content column (30dp side inset, 64dp top
 * inset by default) and a pinned bottom slot — mirrors `FnlScreen`.
 */
@Composable
fun FnlScreen(
    glow: Tone? = Tone.LIME,
    topInset: Int = 64,
    bottom: @Composable ColumnScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        glow?.let { FnlGlow(it) }
        Column(Modifier.fillMaxSize().safeDrawingPadding()) {
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 30.dp)
                    .padding(top = topInset.dp),
                content = content,
            )
            Column(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 30.dp)
                    .padding(bottom = 12.dp),
                content = bottom,
            )
        }
    }
}
