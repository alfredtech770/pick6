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
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.ui.theme.*

/**
 * Edit profile — port of `EditProfileSheet` (Pick1Screens.swift).
 *
 * Email is read-only (identity is the Supabase account); the rest are the
 * optional profile fields. Delete Account sits at the bottom behind a
 * confirmation, matching iOS and App Review's account-deletion requirement.
 */
@Composable
fun EditProfileSheet(
    email: String?,
    onClose: () -> Unit,
    onSave: (first: String, last: String, phone: String, dob: String) -> Unit,
    onDeleteAccount: () -> Unit,
) {
    var first by remember { mutableStateOf("") }
    var last by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var dob by remember { mutableStateOf("") }
    var confirmingDelete by remember { mutableStateOf(false) }

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState()),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 14.dp, bottom = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.profile_edit_title),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.4f),
                color = P1.Mute,
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(R.string.action_done),
                style = archivo(13, FontWeight.Bold),
                color = P1.Lime,
                modifier = Modifier.clickable { onSave(first, last, phone, dob); onClose() },
            )
        }

        Column(
            Modifier.padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            email?.let {
                Field(
                    label = stringResource(R.string.rd_profile_email_label),
                    value = it,
                    enabled = false,
                ) { }
            }
            Field(stringResource(R.string.profile_first_name).uppercase(), first) { first = it }
            Field(stringResource(R.string.profile_last_name).uppercase(), last) { last = it }
            Field(
                stringResource(R.string.rd_profile_phone_label),
                phone,
                keyboard = KeyboardType.Phone,
            ) { phone = it }
            Field(stringResource(R.string.profile_dob).uppercase(), dob) { dob = it }

            Spacer(Modifier.height(10.dp))

            // ── Danger zone ──────────────────────────────────────────
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(P1.Panel)
                    .border(1.dp, P1.Loss.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    stringResource(R.string.profile_delete_account),
                    style = archivo(14, FontWeight.SemiBold),
                    color = P1.Loss,
                    modifier = Modifier.clickable { confirmingDelete = true },
                )
                Text(
                    stringResource(R.string.rd_delete_subtitle),
                    style = archivo(11),
                    color = P1.Mute,
                )
                if (confirmingDelete) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        stringResource(R.string.profile_delete_alert_message),
                        style = archivo(12),
                        color = P1.Ink2,
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(
                            stringResource(R.string.action_cancel),
                            style = archivo(13, FontWeight.Bold),
                            color = P1.Ink2,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(P1.Panel2)
                                .clickable { confirmingDelete = false }
                                .padding(vertical = 12.dp),
                        )
                        Text(
                            stringResource(R.string.profile_delete_alert_confirm),
                            style = archivo(13, FontWeight.Bold),
                            color = P1.Ink,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(P1.Loss)
                                .clickable { onDeleteAccount() }
                                .padding(vertical = 12.dp),
                        )
                    }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun Field(
    label: String,
    value: String,
    enabled: Boolean = true,
    keyboard: KeyboardType = KeyboardType.Text,
    onChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            label,
            style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f),
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
            if (enabled) {
                BasicTextField(
                    value = value,
                    onValueChange = onChange,
                    textStyle = archivo(15).copy(color = P1.Foreground),
                    cursorBrush = SolidColor(P1.Lime),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = keyboard),
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                // Identity is the Supabase account — not editable here.
                Text(value, style = archivo(15), color = P1.Mute)
            }
        }
    }
}
