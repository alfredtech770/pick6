package com.pick1.app.data

import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

/**
 * In-app language switching — the Android counterpart of the iOS
 * `LocalizationManager` + `@AppStorage("appLanguage")`.
 *
 * iOS needed a custom runtime lookup because `Localizable.strings` is keyed
 * off Bundle.main and requires a relaunch. Android solves the same problem
 * natively: `AppCompatDelegate.setApplicationLocales` re-creates the
 * activity with the chosen locale, so every `stringResource` re-resolves
 * against res/values-<lang>/ immediately — no relaunch, no custom lookup.
 *
 * The choice is remembered by the system (and surfaced in Settings > Apps >
 * Pick1 > Language), so it survives reinstalls of the process.
 */
object LanguageManager {

    /** The 7 languages Pick1 ships — same list/order as `ProfileView.languages`. */
    data class Language(
        val code: String,
        val name: String,
        val native: String,
        val flag: String,
    )

    val languages = listOf(
        Language("ar", "Arabic", "العربية الفصحى", "🇸🇦"),
        Language("en", "English", "English", "🇬🇧"),
        Language("fr", "French", "Français", "🇫🇷"),
        Language("de", "German", "Deutsch", "🇩🇪"),
        Language("it", "Italian", "Italiano", "🇮🇹"),
        Language("pt", "Portuguese", "Português", "🇵🇹"),
        Language("es", "Spanish", "Español", "🇪🇸"),
    )

    /**
     * Currently applied language tag, or null when the app is following the
     * device language (the iOS default before a user picks one).
     */
    val current: String?
        get() = AppCompatDelegate.getApplicationLocales()
            .takeIf { !it.isEmpty }
            ?.get(0)
            ?.language

    /** Apply a language immediately; the activity re-creates itself. */
    fun set(code: String) {
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(code)
        )
    }

    /** Fall back to the device language. */
    fun useSystemDefault() {
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.getEmptyLocaleList())
    }

    /** Display name for the settings row's trailing pill. */
    fun displayName(code: String?): String =
        languages.firstOrNull { it.code == code }?.native ?: "System"
}
