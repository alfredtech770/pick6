package com.pick1.app.ui.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.pick1.app.BuildConfig
import com.pick1.app.R
import com.pick1.app.data.*
import com.pick1.app.data.model.Pick
import com.pick1.app.ui.calibration.CalibrationCard
import com.pick1.app.ui.settings.EditProfileSheet
import com.pick1.app.ui.settings.LanguagePickerSheet
import com.pick1.app.ui.settings.PrivacySecuritySheet
import com.pick1.app.ui.settings.SettingsDivider
import com.pick1.app.ui.settings.SettingsRow
import com.pick1.app.ui.settings.SettingsSection
import com.pick1.app.ui.theme.*
import com.pick1.app.ui.tracker.MyBetsCard
import kotlinx.coroutines.launch

/**
 * Profile / settings — port of `ProfileView` (Pick1Screens.swift).
 *
 * The user's own receipts (bet ledger + calibration proof) sit above the
 * grouped settings sections: preferences, support and legal.
 */
class ProfileViewModel : ViewModel() {
    private val bets = BetRepository()
    private val cal = CalibrationRepository()
    private val picksRepo = PicksRepository()

    var summary by mutableStateOf(BetSummary()); private set
    var bands by mutableStateOf<List<CalibrationBand>>(emptyList()); private set
    var avgGap by mutableStateOf<String?>(null); private set

    init {
        viewModelScope.launch {
            val picks: List<Pick> =
                runCatching { picksRepo.gradedHistory(limit = 80) }.getOrDefault(emptyList())
            summary = bets.summary(bets.load().values, picks)
            val b = cal.bands()
            bands = b
            avgGap = cal.avgGapText(b)
        }
    }
}

@Composable
fun ProfileScreen(vm: ProfileViewModel = viewModel()) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var showLanguages by remember { mutableStateOf(false) }
    var showEditProfile by remember { mutableStateOf(false) }
    var showPrivacy by remember { mutableStateOf(false) }

    if (showLanguages) {
        LanguagePickerSheet { showLanguages = false }
        return
    }
    if (showPrivacy) {
        PrivacySecuritySheet(
            email = AuthManager.userEmail,
            onClose = { showPrivacy = false },
            onSavePassword = { true },
        )
        return
    }
    if (showEditProfile) {
        EditProfileSheet(
            email = AuthManager.userEmail,
            onClose = { showEditProfile = false },
            onSave = { _, _, _, _ -> },
            onDeleteAccount = { showEditProfile = false },
        )
        return
    }

    fun open(url: String) {
        runCatching {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.nav_profile).uppercase(),
            style = anton(28),
            color = P1.Foreground,
        )

        // ── The user's receipts ──────────────────────────────────────
        MyBetsCard(vm.summary)
        CalibrationCard(bands = vm.bands, avgGap = vm.avgGap)

        // ── Preferences ──────────────────────────────────────────────
        SettingsSection(
            label = stringResource(R.string.settings_account_section),
            meta = stringResource(R.string.settings_prefs_meta),
        ) {
            SettingsRow(
                Icons.Default.Notifications,
                stringResource(R.string.settings_notifications),
                sub = stringResource(R.string.settings_notifications_sub),
            ) { }
            SettingsDivider()
            SettingsRow(
                Icons.Default.Language,
                stringResource(R.string.settings_language),
                sub = stringResource(R.string.settings_language_sub_default),
                trailing = LanguageManager.displayName(LanguageManager.current),
            ) { showLanguages = true }
            SettingsDivider()
            SettingsRow(
                Icons.Default.WorkspacePremium,
                stringResource(R.string.settings_subscription),
                sub = stringResource(R.string.settings_subscription_sub_free),
                trailing = stringResource(R.string.settings_subscription_free),
            ) { }
            SettingsDivider()
            SettingsRow(
                Icons.Default.Person,
                stringResource(R.string.profile_edit_title),
            ) { showEditProfile = true }
        }

        // ── Support + legal ──────────────────────────────────────────
        SettingsSection(
            label = stringResource(R.string.settings_support_section),
            meta = stringResource(R.string.settings_help_meta),
        ) {
            SettingsRow(
                Icons.Default.HelpOutline,
                stringResource(R.string.settings_help_center),
            ) { open("https://pick1.live/support") }
            SettingsDivider()
            SettingsRow(
                Icons.Default.Lock,
                stringResource(R.string.settings_privacy_security),
            ) { showPrivacy = true }
            SettingsDivider()
            SettingsRow(
                Icons.Default.Description,
                stringResource(R.string.settings_terms),
            ) { open("https://pick1.live/legal/terms") }
            SettingsDivider()
            SettingsRow(
                Icons.Default.Description,
                stringResource(R.string.settings_privacy_policy),
            ) { open("https://pick1.live/legal/privacy") }
            SettingsDivider()
            SettingsRow(
                Icons.AutoMirrored.Filled.ExitToApp,
                stringResource(R.string.settings_sign_out),
                destructive = true,
                showChevron = false,
            ) { scope.launch { AuthManager.signOut() } }
        }

        Text(
            "${stringResource(R.string.settings_app_version)} ${BuildConfig.VERSION_NAME}",
            style = mono(10, FontWeight.Medium),
            color = Color4A,
        )
        Spacer(Modifier.height(96.dp))
    }
}

private val Color4A = androidx.compose.ui.graphics.Color(0xFF4A4B50)
