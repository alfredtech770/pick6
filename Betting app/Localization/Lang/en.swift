// English — canonical source strings.
// Every key must appear here. Other languages may omit keys; missing
// translations fall back to this table.

enum EnglishStrings {
    static let table: [L10nKey: String] = [

        // App / brand
        .app_name:                       "Pick1",
        .app_tagline:                    "AI sports predictions",
        .app_displayname_default:        "PICK1 FAN",

        // Bottom nav
        .nav_home:                       "Home",
        .nav_picks:                      "Picks",
        .nav_live:                       "Live",
        .nav_profile:                    "Profile",
        .nav_live_count_singular:        "Live games, 1 playing now",
        .nav_live_count_plural:          "Live games, {n} playing now",

        // Generic actions
        .action_done:                    "Done",
        .action_cancel:                  "Cancel",
        .action_continue:                "Continue",
        .action_back:                    "Back",
        .action_close:                   "Close",
        .action_save:                    "Save",
        .action_edit:                    "Edit",
        .action_delete:                  "Delete",
        .action_confirm:                 "Confirm",
        .action_retry:                   "Retry",
        .action_skip:                    "Skip",
        .action_next:                    "Next",
        .action_share:                   "Share",

        // State / errors
        .state_loading:                  "Loading…",
        .state_no_picks_today:           "No picks today.",
        .state_offline_title:            "Couldn't reach Pick1",
        .state_offline_body:             "Check your connection and try again.",
        .error_generic:                  "Something went wrong. Please try again.",
        .error_network:                  "Couldn't reach the Pick1 server. Check your connection and try again.",

        // Auth
        .auth_welcome_title:             "Sign in",
        .auth_welcome_sub:               "AI picks across every sport. Make smarter calls.",
        .auth_apple_button:              "Sign in with Apple",
        .auth_or_divider:                "OR",
        .auth_email_placeholder:         "Email address",
        .auth_send_code:                 "Email me a code",
        .auth_code_title:                "Enter your code",
        .auth_code_sub:                  "We sent a 6-digit code to your email.",
        .auth_code_placeholder:          "6-digit code",
        .auth_code_verify:               "Verify",
        .auth_code_resend:               "Resend code",
        .auth_must_be_21:                "Must be 21+ to use Pick1",
        .auth_terms_disclaimer:          "By continuing you agree to our Terms of Service and Privacy Policy.",

        // Settings
        .settings_account_section:       "ACCOUNT",
        .settings_prefs_meta:            "PREFS",
        .settings_notifications:         "Notifications",
        .settings_notifications_sub:     "Live games · picks · results",
        .settings_language:              "Language",
        .settings_language_sub_default:  "System default",
        .settings_subscription:          "Subscription",
        .settings_subscription_free:     "FREE",
        .settings_subscription_pro:      "PRO",
        .settings_subscription_sub_pro:  "Manage in iOS Settings",
        .settings_subscription_sub_free: "Unlock all picks · go Pro",
        .settings_support_section:       "SUPPORT",
        .settings_help_meta:             "HELP",
        .settings_help_center:           "Help center",
        .settings_privacy_security:      "Privacy & Security",
        .settings_terms:                 "Terms of Service",
        .settings_privacy_policy:        "Privacy Policy",
        .settings_sign_out:              "Sign Out",
        .settings_app_version:           "App version",

        // Edit profile
        .profile_edit_title:             "Edit profile",
        .profile_first_name:             "First name",
        .profile_last_name:              "Last name",
        .profile_whatsapp:               "WhatsApp",
        .profile_dob:                    "Date of birth",
        .profile_delete_account:         "Delete Account",
        .profile_delete_alert_title:     "Delete account?",
        .profile_delete_alert_message:   "This permanently deletes your Pick1 account and pick history within 30 days. Active subscriptions must be cancelled separately in iOS Settings → Subscriptions.",
        .profile_delete_alert_confirm:   "Delete",

        // Language picker
        .lang_picker_title:              "LANGUAGE",

        // Paywall
        .paywall_kicker:                 "GO PRO",
        .paywall_title:                  "Unlock every pick.",
        .paywall_subtitle:               "Every sport. Every game. Every day.",
        .paywall_weekly:                 "Weekly",
        .paywall_monthly:                "Monthly",
        .paywall_save_badge:             "SAVE 33%",
        .paywall_best_value:             "BEST VALUE",
        .paywall_compare_title:          "FREE vs PRO",
        .paywall_compare_meta:           "WHAT YOU GET",
        .paywall_faq_title:              "QUESTIONS?",
        .paywall_faq_meta:               "FAQ",
        .paywall_fineprint_weekly:       "7-day free trial, then $14.99/week. Subscription auto-renews unless canceled at least 24h before the period ends. Payments are processed through your Apple ID.",
        .paywall_fineprint_monthly:      "7-day free trial, then $39.99/month. Subscription auto-renews unless canceled at least 24h before the period ends. Payments are processed through your Apple ID.",
        .paywall_then_weekly:            "Then $14.99/week · Cancel anytime",
        .paywall_then_monthly:           "Then $39.99/month · Cancel anytime",
        .paywall_cta_trial:              "Start 7-Day Free Trial",
        .paywall_restore:                "Restore Purchases",
        .paywall_terms:                  "Terms of Service",
        .paywall_privacy:                "Privacy Policy",
        .paywall_manage_subscription:    "Manage Subscription",
        .paywall_skip:                   "Access Free",
        .paywall_purchase_pending:       "Your purchase is pending approval. We'll unlock Pro as soon as it clears.",

        // Cards
        .card_live:                      "LIVE",
        .card_final:                     "FINAL",
        .card_awaiting:                  "AWAITING",
        .card_pending_grade:             "PENDING GRADE",
        .card_vs:                        "VS",
        .card_ai_picks:                  "AI PICKS",
        .card_my_picks:                  "MY PICKS",
        .card_home_team:                 "HOME",
        .card_away_team:                 "AWAY",
        .card_pick_label:                "AI",
        .card_lock_in:                   "LOCK IN AI PICK",
        .card_save_pick:                 "Save pick",
        .card_saved_toast:               "SAVED · {n}% AI CONFIDENCE",

        // Bookmaker / age gate
        .bookmaker_sheet_title:          "PLACE YOUR PICK",
        .bookmaker_disclaimer:           "Pick1 surfaces AI predictions for entertainment. We do not place, accept, or process wagers.",
        .bookmaker_gambler_hotline:      "If you or someone you know has a gambling problem, call 1-800-GAMBLER.",
        .age_gate_title:                 "21+ ONLY",
        .age_gate_message:               "Pick1 surfaces AI sports predictions for entertainment. Sportsbook integrations require you to be 21 or older. By continuing you confirm you meet the legal gambling age in your jurisdiction.\n\nIf you or someone you know has a gambling problem, call 1-800-GAMBLER.",
        .age_gate_confirm:               "I'm 21 or older",

        // Wins
        .wins_tab_title:                 "WINS",
        .wins_empty_title:               "No wins yet.",
        .wins_empty_sub:                 "Settled picks and favorites will land here.",

        // Live
        .live_tab_title:                 "LIVE",
        .live_section_live:              "LIVE NOW",
        .live_section_awaiting:          "AWAITING GRADE",
        .live_section_final:             "FINAL",
        .live_section_upcoming:          "UPCOMING",
        .live_empty_title:               "Nothing live right now.",
        .live_empty_sub:                 "Check back closer to kickoff.",
    ]
}
