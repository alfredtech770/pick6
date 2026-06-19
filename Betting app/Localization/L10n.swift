// L10n.swift
//
// Pick1's runtime localization layer.
//
// Why not Apple's `Localizable.strings`?
//   The standard mechanism requires the user to restart the app for a
//   language change to take effect (it's keyed off Bundle.main, which is
//   resolved at process launch). The Pick1 Profile → Language picker is
//   expected to switch immediately. We get that by reading the choice from
//   `@AppStorage("appLanguage")` on every render and looking up strings in
//   in-process tables — one Dictionary per language, defined in code.
//
// Adding a new key:
//   1. Add it to `L10nKey` below.
//   2. Add the English value to `EnglishStrings.table` (Lang/en.swift).
//   3. Add translations to the six other Lang/<code>.swift files. If a
//      translation is missing, lookup falls back to English, so a new key
//      is safe to ship before translations land.
//
// Adding a new language:
//   1. Add the entry to `LanguageCode.all`.
//   2. Add Lang/<code>.swift with a `Strings.table: [L10nKey: String]`.
//   3. Add the new (code, name, native, flag) tuple to
//      `ProfileView.languages` in Pick1Screens.swift so it shows in the
//      picker.

import SwiftUI
import Combine

// MARK: - Keys

/// Every user-visible string in Pick1 that we translate. Using an enum
/// (vs raw String keys) means the compiler tells us at build time when
/// a screen references a key that doesn't exist — no missing-translation
/// surprises at runtime.
///
/// Convention: `<surface>_<descriptor>` snake-style — keep it stable
/// across translations (the value changes per language, the key does
/// not).
enum L10nKey: String, CaseIterable {

    // ─── App / brand ──────────────────────────────────────────────
    case app_name
    case app_tagline                     // "AI sports predictions"
    case app_displayname_default         // "PICK1 FAN" (fallback display name)

    // ─── Bottom nav ───────────────────────────────────────────────
    case nav_home
    case nav_picks
    case nav_live
    case nav_profile
    case nav_live_count_singular         // "Live games, 1 playing now"  (uses {n})
    case nav_live_count_plural           // "Live games, {n} playing now"

    // ─── Generic actions / words ──────────────────────────────────
    case action_done
    case action_cancel
    case action_continue
    case action_back
    case action_close
    case action_save
    case action_edit
    case action_delete
    case action_confirm
    case action_retry
    case action_skip
    case action_next
    case action_share

    // ─── Common error / state labels ──────────────────────────────
    case state_loading
    case state_no_picks_today
    case state_offline_title
    case state_offline_body
    case error_generic
    case error_network                   // matches AuthManager.friendlyError

    // ─── Auth — sign in / OTP / Apple ─────────────────────────────
    case auth_welcome_title
    case auth_welcome_sub
    case auth_apple_button
    case auth_or_divider
    case auth_email_placeholder
    case auth_send_code
    case auth_code_title
    case auth_code_sub
    case auth_code_placeholder
    case auth_code_verify
    case auth_code_resend
    case auth_must_be_21
    case auth_terms_disclaimer

    // ─── Profile / settings ───────────────────────────────────────
    case settings_account_section
    case settings_prefs_meta
    case settings_notifications
    case settings_notifications_sub
    case settings_language
    case settings_language_sub_default
    case settings_subscription
    case settings_subscription_free
    case settings_subscription_pro
    case settings_subscription_sub_pro
    case settings_subscription_sub_free
    case settings_support_section
    case settings_help_meta
    case settings_help_center
    case settings_privacy_security
    case settings_terms
    case settings_privacy_policy
    case settings_sign_out
    case settings_app_version              // "App version"

    // ─── Edit profile sheet ───────────────────────────────────────
    case profile_edit_title
    case profile_first_name
    case profile_last_name
    case profile_whatsapp
    case profile_dob
    case profile_delete_account
    case profile_delete_alert_title
    case profile_delete_alert_message
    case profile_delete_alert_confirm

    // ─── Language picker ──────────────────────────────────────────
    case lang_picker_title

    // ─── Paywall / subscription ───────────────────────────────────
    case paywall_kicker
    case paywall_title
    case paywall_subtitle
    case paywall_weekly
    case paywall_monthly
    case paywall_save_badge                // "SAVE 33%"
    case paywall_best_value
    case paywall_compare_title
    case paywall_compare_meta
    case paywall_faq_title
    case paywall_faq_meta
    // FAQ accordion (was hardcoded English; now localized + 3-day-trial-correct)
    case paywall_faq_q_cancel
    case paywall_faq_a_cancel
    case paywall_faq_q_trial
    case paywall_faq_a_trial
    case paywall_faq_q_switch
    case paywall_faq_a_switch
    case paywall_fineprint_weekly
    case paywall_fineprint_monthly
    case paywall_then_weekly               // "Then $14.99/week · Cancel anytime"
    case paywall_then_monthly
    // No-trial variants — shown once the Apple ID has already used its
    // one introductory free trial (Apple grants exactly one per
    // subscription group, never reset by cancelling). These promise no
    // trial and bill immediately.
    case paywall_then_weekly_notrial       // "$14.99/week · Auto-renews · Cancel anytime"
    case paywall_then_monthly_notrial
    case paywall_fineprint_weekly_notrial
    case paywall_fineprint_monthly_notrial
    case paywall_cta_trial
    case paywall_cta_subscribe             // weekly (no trial) CTA
    case paywall_restore
    case paywall_terms
    case paywall_privacy
    case paywall_manage_subscription
    case paywall_skip                      // "Access Free"
    case paywall_purchase_pending

    // ─── Home / pick cards ────────────────────────────────────────
    case card_live
    case card_final
    case card_awaiting
    case card_pending_grade
    case card_vs
    case card_ai_picks                     // section header "AI PICKS"
    case card_my_picks
    case card_home_team
    case card_away_team
    case card_pick_label                   // "AI" caps prefix
    case card_save_pick                    // CTA on detail
    case card_saved_toast                  // "SAVED · {n}% AI CONFIDENCE"

    // ─── Age gate ─────────────────────────────────────────────────
    case age_gate_title                    // "18+ ONLY"
    case age_gate_message
    case age_gate_confirm

    // ─── Wins / favorites tab ─────────────────────────────────────
    case wins_tab_title
    case wins_empty_title
    case wins_empty_sub

    // ─── Live tab ─────────────────────────────────────────────────
    case live_tab_title
    case live_section_live
    case live_section_awaiting
    case live_section_final
    case live_section_upcoming
    case live_empty_title
    case live_empty_sub
}

// MARK: - Manager

/// Source of truth for the user's chosen language. Mirrors the
/// `@AppStorage("appLanguage")` key, but published as `@Observable` so
/// views can react when the picker changes the selection.
///
/// `@MainActor` because everything that reads from this is a SwiftUI view
/// path. The reads happen on every body re-evaluation, so this is hot —
/// we keep the lookup branch-free and table-backed.
@MainActor
@Observable
final class LocalizationManager {
    /// BCP-47-ish language code: "en", "fr", "es", "ar", "de", "it", "pt".
    /// Anything else falls back to English.
    var languageCode: String {
        didSet {
            UserDefaults.standard.set(languageCode, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "appLanguage"

    /// Singleton shared by the app + `t(_:)` free function. SwiftUI views
    /// observe it via `@Environment(LocalizationManager.self)` so a
    /// language change re-renders them immediately (no restart).
    static let shared = LocalizationManager()

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? "en"
        self.languageCode = LocalizationManager.normalize(stored)
    }

    /// Map any iOS locale ("en-US", "fr-FR", etc.) onto one of our 7
    /// supported codes. Unknown languages fall back to English.
    static func normalize(_ raw: String) -> String {
        let primary = raw.lowercased().split(separator: "-").first.map(String.init) ?? raw.lowercased()
        return Self.supported.contains(primary) ? primary : "en"
    }

    static let supported: Set<String> = ["en", "ar", "fr", "de", "it", "pt", "es"]

    /// Translate a key in the current language. Falls back to English if
    /// the key is missing from the active language's table (e.g. brand-
    /// new key landed before the translation was added).
    func t(_ key: L10nKey) -> String {
        let table = Self.table(for: languageCode)
        if let translated = table[key] { return translated }
        return EnglishStrings.table[key] ?? key.rawValue
    }

    /// Convenience for keys that include "{n}" placeholders. Pass the int
    /// and we sub it in. Used for counts ("3 live games").
    func t(_ key: L10nKey, count n: Int) -> String {
        let template = t(key)
        return template.replacingOccurrences(of: "{n}", with: String(n))
    }

    /// True for languages that render right-to-left (Arabic in our set).
    var layoutDirection: LayoutDirection {
        languageCode == "ar" ? .rightToLeft : .leftToRight
    }

    /// SwiftUI Locale to hand to formatters (date, number, currency).
    /// We keep formatter calendars in en_US_POSIX for stable parsing of
    /// pipeline-supplied ISO dates; this Locale is only for *display*.
    var displayLocale: Locale {
        Locale(identifier: languageCode)
    }

    /// Internal switchboard. Edited centrally so views never need to
    /// know which file holds which table.
    private static func table(for code: String) -> [L10nKey: String] {
        switch code {
        case "ar": return ArabicStrings.table
        case "fr": return FrenchStrings.table
        case "de": return GermanStrings.table
        case "it": return ItalianStrings.table
        case "pt": return PortugueseStrings.table
        case "es": return SpanishStrings.table
        default:   return EnglishStrings.table
        }
    }
}

// MARK: - Free helpers

/// Shortcut for use inside SwiftUI Views. Views that hold an
/// `@Environment(LocalizationManager.self) var loc` can call `loc.t(.foo)`
/// directly, but for one-off lookups in helper functions where the
/// environment isn't reachable we expose this free function. It uses the
/// shared singleton, so SwiftUI views that depend on its output need to
/// observe `LocalizationManager.shared` themselves to re-render on
/// language change.
@MainActor
func t(_ key: L10nKey) -> String {
    LocalizationManager.shared.t(key)
}

@MainActor
func t(_ key: L10nKey, count n: Int) -> String {
    LocalizationManager.shared.t(key, count: n)
}
