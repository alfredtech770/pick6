package com.pick1.app.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Key
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.theme.*

/**
 * Privacy & Security — port of `PrivacySecuritySheet` (Pick1Screens.swift).
 *
 * Shows the account identity (read-only) and lets the user optionally attach
 * a password. Pick1 sign-in is passwordless by default (email OTP / Google),
 * but Supabase allows a password as a second auth path — the copy says so
 * explicitly, same as iOS.
 */
@Composable
fun PrivacySecuritySheet(
    email: String?,
    onClose: () -> Unit,
    onSavePassword: suspend (String) -> Boolean,
) {
    var newPassword by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var saved by remember { mutableStateOf(false) }

    val canSave = newPassword.length >= 8 && newPassword == confirmPassword

    Column(
        Modifier
            .fillMaxSize()
            .background(Color(0xFF07080A))
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState()),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(top = 12.dp, bottom = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.settings_privacy_security),
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

        Column(
            Modifier.padding(horizontal = 18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // ── Account (read-only identity) ─────────────────────────
            Text(
                stringResource(R.string.settings_account_section),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
                color = P1.Mute,
            )
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(P1.Panel)
                    .border(1.dp, P1.Line, RoundedCornerShape(18.dp)),
            ) {
                InfoRow(Icons.Default.Email, stringResource(R.string.rd_profile_email_label), email ?: "—")
                SettingsDivider()
                InfoRow(
                    Icons.Default.Key,
                    stringResource(R.string.auth_welcome_title),
                    stringResource(R.string.rd_signin_method_magic),
                )
            }

            Spacer(Modifier.height(12.dp))

            // ── Optional password ────────────────────────────────────
            Text(
                stringResource(R.string.rd_profile_change_password),
                style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
                color = P1.Mute,
            )
            Text(
                stringResource(R.string.rd_profile_password_help),
                style = archivo(11, FontWeight.Medium),
                color = P1.Mute,
            )
            PasswordField(stringResource(R.string.rd_new_password), newPassword) {
                newPassword = it; error = null; saved = false
            }
            PasswordField(stringResource(R.string.rd_confirm_password), confirmPassword) {
                confirmPassword = it; error = null; saved = false
            }

            error?.let { Text(it, style = archivo(12), color = P1.Loss) }
            if (saved) {
                Text(
                    stringResource(R.string.rd_password_saved),
                    style = archivo(12, FontWeight.Bold),
                    color = P1.Lime,
                )
            }

            Text(
                stringResource(R.string.action_save),
                style = archivo(14, FontWeight.Bold),
                color = if (canSave) P1.Ink else P1.Mute,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(if (canSave) P1.Lime else P1.Panel2)
                    .clickable(enabled = canSave) {
                        // Validation mirrors iOS: >= 8 chars and matching.
                        newPassword.let { pw ->
                            if (pw.length < 8) error = "Password must be at least 8 characters."
                            else saved = true
                        }
                    }
                    .padding(vertical = 15.dp),
            )
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun InfoRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)).background(P1.Panel2),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, tint = P1.Lime, modifier = Modifier.size(15.dp))
        }
        Text(title, style = archivo(13, FontWeight.SemiBold), color = P1.Foreground)
        Spacer(Modifier.weight(1f))
        Text(value, style = archivo(12), color = P1.Mute)
    }
}

@Composable
private fun PasswordField(label: String, value: String, onChange: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            label,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.0f),
            color = P1.Mute,
        )
        Box(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(P1.Panel)
                .border(1.dp, P1.Line, RoundedCornerShape(14.dp))
                .padding(horizontal = 16.dp, vertical = 15.dp),
        ) {
            BasicTextField(
                value = value,
                onValueChange = onChange,
                textStyle = archivo(15).copy(color = P1.Foreground),
                cursorBrush = SolidColor(P1.Lime),
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
