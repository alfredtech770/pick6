package com.pick1.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
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
import com.pick1.app.data.LanguageManager
import com.pick1.app.ui.theme.*
import com.posthog.PostHog

/**
 * Language picker — port of `LanguagePickerSheet` (Pick1Screens.swift).
 *
 * Selecting a language applies it immediately via the system per-app locale
 * API, which re-creates the activity so every string re-resolves at once —
 * the same "changes mid-session, no relaunch" behaviour as iOS.
 */
@Composable
fun LanguagePickerSheet(onClose: () -> Unit) {
    val current = LanguageManager.current

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState()),
    ) {
        // Header
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(top = 14.dp, bottom = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.lang_picker_title),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.4f),
                color = P1.Mute,
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.action_done),
                style = archivo(13, FontWeight.Bold),
                color = P1.Lime,
                modifier = Modifier.clickable { onClose() },
            )
        }

        // Rows
        Column(
            Modifier
                .padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(22.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(22.dp)),
        ) {
            LanguageManager.languages.forEachIndexed { i, lang ->
                LanguageRow(lang, selected = current == lang.code) {
                    LanguageManager.set(lang.code)
                    PostHog.capture("language_changed", properties = mapOf("language" to lang.code))
                    onClose()
                }
                if (i != LanguageManager.languages.lastIndex) {
                    Box(
                        Modifier
                            .padding(start = 56.dp)
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(P1.Line),
                    )
                }
            }
        }
        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun LanguageRow(
    lang: LanguageManager.Language,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Flag tile — the active language gets a lime-tinted ring.
        Box(
            Modifier
                .size(38.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(P1.Panel2)
                .border(
                    1.dp,
                    if (selected) P1.Lime.copy(alpha = 0.4f) else P1.Line,
                    RoundedCornerShape(10.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(lang.flag, style = archivo(20))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(lang.name, style = archivo(13, FontWeight.SemiBold), color = P1.Foreground)
            Text(lang.native, style = mono(10, FontWeight.Medium), color = P1.Mute)
        }
        if (selected) {
            Icon(Icons.Default.Check, null, tint = P1.Lime, modifier = Modifier.size(16.dp))
        }
    }
}
