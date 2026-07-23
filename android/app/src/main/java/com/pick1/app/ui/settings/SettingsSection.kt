package com.pick1.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pick1.app.ui.theme.*

/**
 * Grouped settings card + row — ports the settings list styling used by
 * `ProfileView` (Pick1Screens.swift): a section label, then rows inside a
 * rounded panel separated by hairlines, each with an icon tile, title,
 * optional subtitle, an optional trailing pill, and a chevron.
 */
@Composable
fun SettingsSection(
    label: String,
    meta: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                label,
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.4f),
                color = P1.Mute,
            )
            meta?.let {
                Spacer(Modifier.weight(1f))
                Text(it, style = mono(10, FontWeight.Medium), color = Color(0xFF4A4B50))
            }
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(22.dp)),
            content = content,
        )
    }
}

@Composable
fun SettingsRow(
    icon: ImageVector,
    title: String,
    sub: String? = null,
    trailing: String? = null,
    destructive: Boolean = false,
    showChevron: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            Modifier
                .size(34.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(P1.Panel2),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = if (destructive) P1.Loss else P1.Lime,
                modifier = Modifier.size(16.dp),
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title,
                style = archivo(14, FontWeight.SemiBold),
                color = if (destructive) P1.Loss else P1.Foreground,
            )
            sub?.let { Text(it, style = archivo(11), color = P1.Mute) }
        }
        trailing?.let {
            Text(
                it,
                style = archivoNarrow(10, FontWeight.Bold, tracking = 1.2f),
                color = P1.Ink2,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(P1.Panel2)
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
        if (showChevron) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = Color(0xFF4A4B50),
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
fun SettingsDivider() {
    Box(
        Modifier
            .padding(start = 56.dp)
            .fillMaxWidth()
            .height(1.dp)
            .background(P1.Line),
    )
}
