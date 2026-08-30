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
    // Track-record social proof strip
    case paywall_track_kicker              // "PROVEN RESULTS"
    case paywall_track_accuracy            // "ACCURACY"
    case paywall_track_wins                // "WINS"
    case paywall_track_graded              // "GRADED PICKS"

    // ─── Referral / invite ────────────────────────────────────────
    case referral_title
    case referral_subtitle
    case referral_your_code
    case referral_share_cta
    case referral_have_code
    case referral_enter
    case referral_redeem
    case referral_redeemed
    case code_applied                      // creator/affiliate code: attribution only, no Pro
    case referral_err_invalid
    case referral_err_used
    case referral_share_msg                // "...code %@ ... %@" (code, url)

    // ─── Update prompt (new App Store version available) ──────────
    case update_title
    case update_body
    case update_cta
    case update_later

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
    case card_unlock_pro                    // concealed upcoming-event pick (Free)

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

    // ─── Onboarding funnel ────────────────────────────────────────
    // Welcome
    case funnel_welcome_headline          // "WIN\nSMARTER.\n*NOT HARDER.*"
    case funnel_welcome_lead              // hero subhead
    case funnel_welcome_cta               // "GET STARTED →"
    case funnel_welcome_member            // "Already a member? "
    case funnel_welcome_signin            // "Sign in"
    // Features
    case funnel_feat_kicker               // "Meet Pick1"
    case funnel_feat_headline             // "ONE APP.\nEVERY *EDGE.*"
    case funnel_feat1_title
    case funnel_feat1_body
    case funnel_feat2_title
    case funnel_feat2_body
    case funnel_feat3_title
    case funnel_feat3_body
    case funnel_feat4_title
    case funnel_feat4_body
    case funnel_continue_cta              // "CONTINUE →"
    // Signup
    case funnel_signup_kicker             // "Analysis ready · save your results"
    case funnel_signup_kicker_otp         // "Check your email"
    case funnel_signup_headline           // "JOIN A\nCOMMUNITY\nOF *WINNERS.*"
    case funnel_signup_headline_otp       // "ENTER\n*YOUR CODE.*"
    case funnel_signup_or                 // "OR"
    case funnel_signup_email_label        // "Email"
    case funnel_signup_email_ph           // "you@email.com"
    case funnel_signup_otp_sent           // "We sent a 6-digit code to {email}. Enter it to finish signing in."
    case funnel_signup_code_label         // "Verification code"
    case funnel_signup_code_ph            // "123456"
    case funnel_signup_diff_email         // "Use a different email"
    case funnel_signup_cta_verify         // "VERIFY →"
    case funnel_signup_cta_email          // "CONTINUE WITH EMAIL →"
    case funnel_signup_terms              // "BY JOINING YOU AGREE TO OUR TERMS · 21+"
    // Quiz
    case funnel_quiz_progress             // "Question {n} of 5"
    case funnel_quiz1_q
    case funnel_quiz1_opt1
    case funnel_quiz1_opt2
    case funnel_quiz1_opt3
    case funnel_quiz1_opt4
    case funnel_quiz2_q
    case funnel_quiz2_opt1
    case funnel_quiz2_opt2
    case funnel_quiz2_opt3
    case funnel_quiz2_opt4
    case funnel_quiz3_q
    case funnel_quiz3_opt1
    case funnel_quiz3_opt2
    case funnel_quiz3_opt3
    case funnel_quiz3_opt4
    case funnel_quiz4_q
    case funnel_quiz4_opt1
    case funnel_quiz4_opt2
    case funnel_quiz4_opt3
    case funnel_quiz4_opt4
    case funnel_quiz5_q
    case funnel_quiz5_opt1
    case funnel_quiz5_opt2
    case funnel_quiz5_opt3
    case funnel_quiz5_opt4
    // Analysis
    case funnel_analysis_kicker           // "Analyzing your answers"
    case funnel_analysis_row1
    case funnel_analysis_row2
    case funnel_analysis_row3
    case funnel_analysis_row4
    // Red "hard truth"
    case funnel_red_kicker                // "The hard truth · {n} of 4"
    case funnel_red1_headline
    case funnel_red1_lead
    case funnel_red1_ct
    case funnel_red1_cb
    case funnel_red1_cta
    case funnel_red2_headline
    case funnel_red2_lead
    case funnel_red2_ct
    case funnel_red2_cb
    case funnel_red2_cta
    case funnel_red3_headline
    case funnel_red3_unit                 // "records"
    case funnel_red3_lead
    case funnel_red3_ct
    case funnel_red3_cb
    case funnel_red3_cta
    case funnel_red4_headline
    case funnel_red4_unit                 // "%/bet"
    case funnel_red4_lead
    case funnel_red4_ct
    case funnel_red4_cb
    case funnel_red4_cta
    // Green "the fix"
    case funnel_green1_kicker
    case funnel_green1_headline
    case funnel_green1_lead
    case funnel_green1_cta
    case funnel_green2_kicker
    case funnel_green2_headline
    case funnel_green2_lead
    case funnel_green2_cta
    case funnel_green3_kicker
    case funnel_green3_headline
    case funnel_green3_lead
    case funnel_green3_cta
    // Green preview cards
    case funnel_green_pill_pick           // "★ Today's top pick"
    case funnel_green_ai_conf             // "AI CONFIDENCE"
    case funnel_green_pill_why            // "▸ Why the AI likes it"
    case funnel_green_pill_ledger         // "▸ Public ledger"
    case funnel_green_won                 // "WON"
    case funnel_green_loss                // "LOSS"
    // Social proof
    case funnel_social_kicker             // "The record speaks"
    case funnel_social_headline           // "NOTHING\nTO *HIDE.*"
    case funnel_social1_title
    case funnel_social1_sub
    case funnel_social2_title
    case funnel_social2_sub
    case funnel_social3_title
    case funnel_social3_sub
    case funnel_social_disclaimer         // "Past performance doesn't guarantee future results."
    case funnel_social_cta                // "I WANT IN →"
    // Compare
    case funnel_compare_kicker            // "Why Pick1 wins"
    case funnel_compare_headline          // "THE *DIFFERENCE.*"
    case funnel_compare_col_feature       // "FEATURE"
    case funnel_compare_col_others        // "OTHERS"
    case funnel_compare_col_pick1         // "PICK1"
    case funnel_compare_row1
    case funnel_compare_row2
    case funnel_compare_row3
    case funnel_compare_row4
    case funnel_compare_row5
    case funnel_compare_row6
    // Goals
    case funnel_goals_kicker              // "Set your target"
    case funnel_goals_headline            // "WHAT'S YOUR\n*GOAL?*"
    case funnel_goals_lead
    case funnel_goal1
    case funnel_goal2
    case funnel_goal3
    case funnel_goal4
    // Notifications
    case funnel_notif_kicker              // "Never miss a call"
    case funnel_notif_headline            // "YOUR PICK.\nTHE SECOND\n*IT DROPS.*"
    case funnel_notif_lead
    case funnel_notif_perk1
    case funnel_notif_perk2
    case funnel_notif_perk3
    case funnel_notif_cta                 // "TURN ON ALERTS →"
    case funnel_notif_skip                // "Not now"
    // Referral
    case funnel_ref_kicker                // "Got a code?"
    case funnel_ref_headline              // "UNLOCK\nYOUR *BONUS.*"
    case funnel_ref_lead
    case funnel_ref_field_label           // "Referral code (optional)"
    case funnel_ref_field_ph              // "PICK1-XXXX"
    case funnel_ref_cta                   // "CONTINUE →"
    case funnel_ref_skip                  // "Skip for now"
    case funnel_ref_ok_pro                // "🎉 Code applied — a free week of Pro is on us!"
    case funnel_ref_ok                    // "✓ Code applied!"
    case funnel_ref_err_invalid           // "That code isn't valid."
    case funnel_ref_err_used              // "You've already used a code."
    case funnel_ref_err_generic           // "Something went wrong — try again."
    // Rating
    case funnel_rating_kicker             // "Help us grow"
    case funnel_rating_headline           // "LOVE *PICK1?*"
    case funnel_rating_lead
    case funnel_rating_bonus_title        // "+3 DAYS"
    case funnel_rating_bonus_sub
    case funnel_rating_cta                // "RATE & CLAIM →"
    case funnel_rating_skip               // "Maybe later"
    // Time to win
    case funnel_ttw_kicker                // "You're all set"
    case funnel_ttw_headline              // "NOW IT'S\nTIME TO\n*WIN.*"
    case funnel_ttw_lead
    case funnel_ttw_cta                   // "SEE MY PLAN →"
    // Paywall
    case funnel_paywall_kicker            // "Go Pro"
    case funnel_paywall_headline          // "UNLOCK\nEVERY *PICK.*"
    case funnel_paywall_feat1
    case funnel_paywall_feat2
    case funnel_paywall_feat3
    case funnel_paywall_feat4
    case funnel_paywall_loading           // "Loading plans…"
    case funnel_paywall_cta_continue      // "CONTINUE →"
    case funnel_paywall_cta_unlock        // "UNLOCK PICK1 PRO →"
    case funnel_paywall_fineprint         // "NO FREE TRIAL · CANCEL ANYTIME · SECURE CHECKOUT" (shown when trial not available/eligible)
    case funnel_paywall_fineprint_trial   // "3-DAY FREE TRIAL · CANCEL ANYTIME · SECURE CHECKOUT"
    case funnel_paywall_trial_badge       // "3 DAYS FREE" (weekly plan card badge)
    case funnel_paywall_cta_trial         // "START 3-DAY FREE TRIAL →"
    case funnel_paywall_restore           // "Restore"
    case funnel_paywall_terms             // "Terms"
    case funnel_paywall_privacy           // "Privacy"
    case funnel_paywall_continue_free     // "Continue free →"
    case funnel_paywall_plan_weekly       // "WEEKLY"
    case funnel_paywall_plan_monthly      // "MONTHLY"
    case funnel_paywall_plan_lifetime     // "LIFETIME"
    case funnel_paywall_plan_daypass      // "DAY PASS"
    case funnel_paywall_unit_day          // "/24h"
    case funnel_paywall_sub_daypass       // "One game day · every pick · no subscription"
    case funnel_paywall_unit_wk           // "/wk"
    case funnel_paywall_unit_mo           // "/mo"
    case funnel_paywall_best_value        // "BEST VALUE"
    case funnel_paywall_sub_lifetime      // "One-time · yours forever"
    case funnel_paywall_sub_weekly        // "Billed weekly · cancel anytime"
    case funnel_paywall_sub_monthly       // "Billed monthly · cancel anytime"
    case funnel_paywall_goal1             // goalEcho variants
    case funnel_paywall_goal2
    case funnel_paywall_goal3
    case funnel_paywall_goal4
    // Success
    case funnel_success_headline          // "YOU'RE IN.\nLET'S *WIN.*"
    case funnel_success_body_pro
    case funnel_success_body_free
    case funnel_success_cta               // "START YOUR JOURNEY →"

    // ─── 2026-07 redesign surfaces (home/detail/live/picks) ───────
    case rd_sport_tennis
    case sw_share_win
    case sw_your_amount
    case sw_would_have
    case sw_share_cta
    case sw_reward_hint
    case sw_reward_done
    case sw_disclaimer
    case sw_day_pass_line
    case sw_members_title
    case sc_share_streak                  // "SHARE YOUR STREAK"
    case sc_day_streak                    // "DAY WIN STREAK"
    case sc_top_pick_note                 // "AI'S #1 PICK OF THE DAY"
    case sc_ai_record                     // "ALL-TIME AI RECORD"
    case sc_my_record                     // "MY RECORD"
    case sc_share_record_cta              // "SHARE MY RECORD"
    case rd_upcoming_football
    case rd_predicted_score
    case rd_market_odds
    case rd_est_from_conf
    case rd_ai_edge
    case rd_confidence_label
    case rd_status
    case rd_ai_picks
    case rd_win_prob
    case rd_possible_return
    case rd_todays_games
    case rd_latest_wins
    case rd_see_all
    case rd_missed_win
    case rd_full_slate
    case rd_premium
    case rd_ai_pick_hidden
    case rd_unlock
    case rd_more_picks_inside
    case rd_won
    case rd_lost
    case rd_ai_powered
    case rd_prem_pill
    case rd_prem_head
    case rd_prem_head_accent
    case rd_prem_body
    case rd_prem_check1
    case rd_prem_check2
    case rd_prem_check3
    case rd_prem_check4
    case rd_prem_cta_trial
    case rd_prem_cta
    case rd_all_sports
    case rd_sport_basketball
    case rd_sport_soccer
    case rd_sport_golf
    case rd_sport_hockey
    case rd_sport_cricket
    case rd_our_call
    case rd_ai_analysis
    case rd_team_stats
    case rd_fighters
    case rd_field
    case rd_players
    case rd_pick1s_call
    case rd_unlocked
    case rd_track_your_pick
    case rd_tracking
    case rd_logged
    case rd_confidence_prefix
    case rd_potential_payout
    case rd_odds_if_hits
    case rd_were_backing
    case rd_our_read
    case rd_market_implied
    case rd_fair_price
    case rd_value_label
    case rd_no_edge
    case rd_value_sub
    case rd_no_edge_sub
    case rd_fair_price_body
    case rd_more_predictions
    case rd_why
    case rd_breakdown
    case rd_best
    case rd_no_bets
    case rd_potential_return
    case rd_not_advice
    case rd_est
    case rd_why_ai_likes
    case rd_ai_confidence
    case rd_matchup
    case rd_projection
    case rd_tale_of_tape
    case rd_career
    case rd_form_guide
    case rd_verified_web
    case rd_verified_espn_stats
    case rd_verified_espn
    case rd_recent_form
    case rd_see_pick1s_call
    case rd_hidden
    case rd_unlock_pick_trial
    case rd_unlock_pick
    case rd_best_value_today
    case rd_beat_market
    case rd_ai_projection_disc
    case rd_pick1_pro
    case rd_unlock_with_pro
    case rd_no_games_today
    case rd_picks_drop
    case rd_trial_badge
    case rd_go_pro_from
    case rd_your
    case rd_picks_word
    case rd_saved_matches
    case rd_tap_star_favorite
    case rd_matches_count
    case rd_clear_all
    case rd_remove_all_q
    case rd_no_saved_title
    case rd_no_saved_sub
    case rd_ai_pick
    case rd_track
    case rd_record
    case rd_on_graded
    case rd_all_filter
    case rd_no_graded_title
    case rd_no_graded_sub
    case rd_now_word
    case rd_live_word
    case rd_games_n
    case rd_picks_in_play
    case rd_favorites
    case rd_in_play
    case rd_n_live
    case rd_n_saved
    case rd_next_up
    case rd_starting_now
    case rd_your_pick
    case rd_nothing_live
    case rd_nothing_live_sub
    case rd_no_sport_picks
    case rd_final_w
    case rd_final_l
    case rd_pending_grade
    case rd_ai_called_it
    case rd_home_label
    case rd_away_label
    case rd_our_pick_to_win
    case rd_top_ai_pick_today
    case rd_ai_pick_race_winner
    case rd_podium_probs
    case rd_win_podium_chance
    case rd_win_word
    case rd_podium_word
    case rd_yesterday
    case rd_standings
    case rd_top5
    case rd_team_col
    case rd_standings_load
    case rd_wins_tile
    case rd_accuracy
    case rd_building_record
    case rd_on_fire
    case rd_loading_picks
    case rd_picks_stats_glory
    case rd_crumb_you
    case rd_crumb_now
    case rd_crumb_home
    case rd_crumb_today
    case rd_todays_word
    case rd_avg_conf
    case rd_n_picks
    // 2026-07 language-completeness sweep (summer-football/tracker/calibration)
    case rd_sf_title
    case rd_sf_summer_football
    case rd_sf_every_match
    case rd_sf_every_match_nl
    case rd_sf_call
    case rd_sf_unlock_pro
    case rd_sf_next_fixtures
    case rd_sf_predictions_land
    case rd_sf_ai_by
    case rd_sf_group_stage
    case rd_bt_track_this
    case rd_bt_ledger
    case rd_bt_empty
    case rd_bt_on
    case rd_bt_staked_across
    case rd_bt_to_return
    case rd_cal_title
    case rd_cal_tagline
    case rd_cal_alltime
    case rd_no_market_line
    case rd_best_line_books
    case rd_over_prefix
    case rd_save_changes
    case rd_delete_subtitle
    // 2026-07 language-completeness sweep (part 2)
    case rd_every_pick_line
    case rd_cancel_anytime
    case rd_bt_stake_sub
    case rd_bt_amount
    case rd_bt_track_without_stake
    case rd_bt_track_bet
    case rd_bt_n_tracked
    case rd_cal_gap_pre
    case rd_cal_gap_post
    case rd_cal_we_said
    case rd_cal_actually_hit
    case rd_bt_record
    case rd_bt_hit_rate
    case rd_bt_pending
    case rd_cal_pct_hit
    case rd_ob_every
    case rd_ob_result
    case rd_profile_change_password
    case rd_profile_email_label
    case rd_profile_phone_label
    case rd_profile_password_help
    case rd_legal_load_pre
    case rd_legal_load_post
    case rd_free_lock_copy
    case rd_of_n_this_week
    case rd_unlock_more_one
    case rd_unlock_more_other

    // Recovery surfaces: a subscription stuck in billing retry, and a
    // trial the user has already switched off.
    case rec_billing_title
    case rec_billing_body
    case rec_billing_cta
    case rec_billing_dismiss
    case rec_trial_banner_title
    case rec_trial_banner_body
    case rec_trial_banner_cta

    // Same-unit price comparison, and the annual plan.
    case paywall_per_month_suffix
    case paywall_plan_annual
    case paywall_unit_yr
    case paywall_sub_annual

    // Pick ticket header on the match detail page.
    case tk_confidence
    case tk_to_win
    case tk_returns
    case tk_no_market_short
    case tk_logged
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
        // First launch: follow the phone's language (normalized onto our
        // 7 supported codes; anything else → English). Once the user
        // picks a language in Profile → Language, that stored choice
        // wins forever after.
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
            ?? Locale.preferredLanguages.first
            ?? "en"
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

// MARK: - Live re-localization for detached view trees

/// Views that call the free `t()` helper don't individually observe
/// `LocalizationManager`, so they only re-localize when an ancestor that
/// DOES observe it rebuilds them. The main tab tree gets that for free
/// (the root reads `localization`), but **sheets and fullScreenCovers are
/// a detached tree** — they don't rebuild when the root does, so their
/// `t()` strings stayed in the old language after a language switch.
///
/// Applying `.relocalizesOnLanguageChange()` to a sheet's content makes it
/// observe the manager and rebuild (via `.id`) whenever the language
/// changes — so every `t()` inside re-runs. It also carries the correct
/// layout direction into the sheet so Arabic reads right-to-left there too.
private struct RelocalizeOnLanguageChange: ViewModifier {
    @Environment(LocalizationManager.self) private var loc
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, loc.layoutDirection)
            .id(loc.languageCode)
    }
}

extension View {
    /// Rebuild this subtree when the app language changes. Apply to sheet /
    /// fullScreenCover content so `t()` strings inside re-localize live.
    func relocalizesOnLanguageChange() -> some View {
        modifier(RelocalizeOnLanguageChange())
    }
}
