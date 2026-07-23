package com.pick1.app.ui.calibration

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.CalibrationBand
import com.pick1.app.ui.theme.*
import kotlin.math.roundToInt

private val Lime = Color(0xFFD4FF3A)

/**
 * "Do we mean it?" — proof that Pick1's stated confidence matches reality.
 * Port of `CalibrationCard` (CalibrationView.swift).
 *
 * Each band renders as a paired bar: what we SAID (muted, behind) vs what
 * actually HIT (lime, in front). Straight from the public `calibration_bands`
 * view, so it's honest by construction — no competitor shows this.
 */
@Composable
fun CalibrationCard(
    bands: List<CalibrationBand>,
    avgGap: String?,
    modifier: Modifier = Modifier,
) {
    if (bands.size < 2) return

    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xFF101216))
            .border(1.dp, Color(0xFF1C1F25), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                stringResource(R.string.rd_cal_title),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.0f),
                color = P1.Mute,
            )
            Text(
                stringResource(R.string.rd_cal_tagline),
                style = anton(19),
                color = P1.Foreground,
            )
            avgGap?.let {
                Text(
                    stringResource(R.string.rd_cal_gap_pre) + it + stringResource(R.string.rd_cal_gap_post),
                    style = archivo(12),
                    color = Color(0xFF8A8D94),
                )
            }
        }

        Column(
            Modifier.padding(top = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            bands.forEach { BandRow(it) }
        }

        // Legend
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LegendDot(Color(0xFF4A4B50), stringResource(R.string.rd_cal_we_said))
            LegendDot(Lime, stringResource(R.string.rd_cal_actually_hit))
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.rd_cal_alltime),
                style = archivoNarrow(8, FontWeight.Bold, tracking = 1.0f),
                color = Color(0xFF4A4B50),
            )
        }
    }
}

@Composable
private fun BandRow(b: CalibrationBand) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(b.band, style = archivo(12, FontWeight.Bold), color = P1.Ink2)
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.rd_cal_pct_hit, b.actualPct.roundToInt()),
                style = archivo(12, FontWeight.Bold),
                color = Lime,
            )
            Spacer(Modifier.width(6.dp))
            Text("· n=${b.n}", style = archivo(11), color = Color(0xFF4A4B50))
        }
        // Paired bars: "we said" behind, "actually hit" in front.
        Box(
            Modifier
                .fillMaxWidth()
                .height(6.dp),
        ) {
            Box(
                Modifier
                    .fillMaxWidth((b.avgStated / 100.0).toFloat().coerceIn(0f, 1f))
                    .height(6.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2A2D33)),
            )
            Box(
                Modifier
                    .fillMaxWidth((b.actualPct / 100.0).toFloat().coerceIn(0f, 1f))
                    .height(6.dp)
                    .clip(CircleShape)
                    .background(Lime),
            )
        }
    }
}

@Composable
private fun LegendDot(c: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(
            Modifier
                .size(7.dp)
                .clip(CircleShape)
                .background(c),
        )
        Text(
            label,
            style = archivoNarrow(9, FontWeight.Bold, tracking = 0.8f),
            color = Color(0xFF8A8D94),
        )
    }
}
