package com.pick1.app.ui.free

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.Sport
import com.pick1.app.ui.components.TeamLogo
import com.pick1.app.ui.theme.*

/**
 * Free-tier match detail — port of `FreeMatchDetailView`.
 *
 * Shows the matchup honestly but keeps the actual call behind gold locks:
 * blurred "blobs" stand in for the hidden pick, and every locked row opens
 * the paywall. The free user sees that a call EXISTS and when it was logged,
 * which is the whole tease.
 */
@Composable
fun FreeMatchDetailScreen(pick: Pick, onClose: () -> Unit, onUnlock: () -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding(),
    ) {
        // Header
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
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
            Spacer(Modifier.size(38.dp))
        }

        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            // Matchup — shown in full; there's nothing to hide here.
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(P1.Panel)
                    .border(1.dp, P1.Line, RoundedCornerShape(18.dp))
                    .padding(vertical = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    TeamLogo(pick.sport, pick.awayTeam, pick.awayLogo, size = 58)
                    Text(
                        stringResource(R.string.card_vs),
                        style = anton(16),
                        color = P1.Lime.copy(alpha = 0.8f),
                    )
                    TeamLogo(pick.sport, pick.homeTeam, pick.homeLogo, size = 58)
                }
                Text(
                    "${Sport.short(pick.awayTeam)} — ${Sport.short(pick.homeTeam)}",
                    style = anton(18),
                    color = P1.Foreground,
                )
            }

            // ── PICK1'S CALL (locked) ────────────────────────────────
            SectionHead("PICK1'S CALL")
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(Color(0xFF241D0B), Color(0xFF151107)),
                            start = Offset.Zero, end = Offset.Infinite,
                        )
                    )
                    .border(1.dp, Gold.copy(alpha = 0.45f), RoundedCornerShape(20.dp))
                    .clickable { onUnlock() }
                    .padding(vertical = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(
                    Icons.Default.Lock,
                    null,
                    tint = Gold,
                    modifier = Modifier
                        .clip(CircleShape)
                        .border(1.2.dp, Gold.copy(alpha = 0.7f), CircleShape)
                        .padding(horizontal = 14.dp, vertical = 7.dp)
                        .size(13.dp),
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    BlurBlob(74)
                    Text(
                        stringResource(R.string.rd_see_pick1s_call),
                        style = anton(20),
                        color = Color.White,
                    )
                    BlurBlob(52)
                }
                Text(
                    stringResource(R.string.rd_free_lock_copy),
                    style = archivo(13),
                    color = Color(0xFFCDB98A).copy(alpha = 0.85f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 18.dp),
                )
            }

            // ── WHY · CONFIDENCE BREAKDOWN (locked rows) ─────────────
            SectionHead("WHY · CONFIDENCE BREAKDOWN")
            listOf(
                R.string.rd_why_ai_likes,
                R.string.rd_our_read,
                R.string.rd_more_predictions,
            ).forEach { row ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(P1.Panel)
                        .border(1.dp, P1.Line, RoundedCornerShape(14.dp))
                        .clickable { onUnlock() }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Default.Lock, null, tint = Gold, modifier = Modifier.size(13.dp))
                    Text(
                        stringResource(row),
                        style = archivo(13, FontWeight.SemiBold),
                        color = P1.Ink2,
                        modifier = Modifier.weight(1f),
                    )
                    BlurBlob(44)
                }
            }

            // Unlock CTA
            Text(
                stringResource(R.string.rd_prem_cta),
                style = anton(17, tracking = 0.4f),
                color = Color(0xFF14110A),
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Brush.verticalGradient(listOf(Color(0xFFF2D468), Gold)))
                    .clickable { onUnlock() }
                    .padding(vertical = 16.dp),
            )
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun SectionHead(title: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            title,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
            color = P1.Mute,
        )
        Spacer(Modifier.weight(1f))
        Row(
            Modifier
                .clip(CircleShape)
                .background(Color(0xFF2A230F))
                .padding(horizontal = 9.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(Icons.Default.Lock, null, tint = Gold, modifier = Modifier.size(9.dp))
            Text(
                stringResource(R.string.rd_premium),
                style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                color = Gold,
            )
        }
    }
}

/** Soft gold blur blob — stands in for the hidden pick text. */
@Composable
private fun BlurBlob(width: Int) {
    Box(
        Modifier
            .width(width.dp)
            .height(16.dp)
            .blur(7.dp)
            .clip(CircleShape)
            .background(Gold.copy(alpha = 0.5f)),
    )
}
