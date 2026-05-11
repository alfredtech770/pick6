// French — manually translated from en.swift.
// Brand names, Pick1, USD currency stay verbatim.

enum FrenchStrings {
    static let table: [L10nKey: String] = [

        // App / brand
        .app_name:                       "Pick1",
        .app_tagline:                    "Prédictions sportives par IA",
        .app_displayname_default:        "FAN PICK1",

        // Bottom nav
        .nav_home:                       "Accueil",
        .nav_picks:                      "Picks",
        .nav_live:                       "En direct",
        .nav_profile:                    "Profil",
        .nav_live_count_singular:        "Matchs en direct, 1 en cours",
        .nav_live_count_plural:          "Matchs en direct, {n} en cours",

        // Generic actions
        .action_done:                    "OK",
        .action_cancel:                  "Annuler",
        .action_continue:                "Continuer",
        .action_back:                    "Retour",
        .action_close:                   "Fermer",
        .action_save:                    "Enregistrer",
        .action_edit:                    "Modifier",
        .action_delete:                  "Supprimer",
        .action_confirm:                 "Confirmer",
        .action_retry:                   "Réessayer",
        .action_skip:                    "Passer",
        .action_next:                    "Suivant",
        .action_share:                   "Partager",

        // State / errors
        .state_loading:                  "Chargement…",
        .state_no_picks_today:           "Aucun pick aujourd'hui.",
        .state_offline_title:            "Connexion à Pick1 impossible",
        .state_offline_body:             "Vérifiez votre connexion et réessayez.",
        .error_generic:                  "Une erreur s'est produite. Veuillez réessayer.",
        .error_network:                  "Impossible de joindre le serveur Pick1. Vérifiez votre connexion et réessayez.",

        // Auth
        .auth_welcome_title:             "Se connecter",
        .auth_welcome_sub:               "Picks IA pour tous les sports. Misez plus malin.",
        .auth_apple_button:              "Se connecter avec Apple",
        .auth_or_divider:                "OU",
        .auth_email_placeholder:         "Adresse e-mail",
        .auth_send_code:                 "M'envoyer un code",
        .auth_code_title:                "Saisissez votre code",
        .auth_code_sub:                  "Nous avons envoyé un code à 6 chiffres à votre adresse e-mail.",
        .auth_code_placeholder:          "Code à 6 chiffres",
        .auth_code_verify:               "Vérifier",
        .auth_code_resend:               "Renvoyer le code",
        .auth_must_be_21:                "Réservé aux 21 ans et plus",
        .auth_terms_disclaimer:          "En continuant, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité.",

        // Settings
        .settings_account_section:       "COMPTE",
        .settings_prefs_meta:            "PRÉFS",
        .settings_notifications:         "Notifications",
        .settings_notifications_sub:     "Matchs en direct · picks · résultats",
        .settings_language:              "Langue",
        .settings_language_sub_default:  "Par défaut",
        .settings_subscription:          "Abonnement",
        .settings_subscription_free:     "GRATUIT",
        .settings_subscription_pro:      "PRO",
        .settings_subscription_sub_pro:  "Gérer dans les Réglages iOS",
        .settings_subscription_sub_free: "Tous les picks · passez Pro",
        .settings_support_section:       "ASSISTANCE",
        .settings_help_meta:             "AIDE",
        .settings_help_center:           "Centre d'aide",
        .settings_privacy_security:      "Confidentialité et sécurité",
        .settings_terms:                 "Conditions d'utilisation",
        .settings_privacy_policy:        "Politique de confidentialité",
        .settings_sign_out:              "Se déconnecter",
        .settings_app_version:           "Version de l'app",

        // Edit profile
        .profile_edit_title:             "Modifier le profil",
        .profile_first_name:             "Prénom",
        .profile_last_name:              "Nom",
        .profile_whatsapp:               "WhatsApp",
        .profile_dob:                    "Date de naissance",
        .profile_delete_account:         "Supprimer le compte",
        .profile_delete_alert_title:     "Supprimer le compte ?",
        .profile_delete_alert_message:   "Cette action supprime définitivement votre compte Pick1 et votre historique de picks sous 30 jours. Les abonnements actifs doivent être annulés séparément dans Réglages iOS → Abonnements.",
        .profile_delete_alert_confirm:   "Supprimer",

        // Language picker
        .lang_picker_title:              "LANGUE",

        // Paywall
        .paywall_kicker:                 "PASSEZ PRO",
        .paywall_title:                  "Débloquez chaque pick.",
        .paywall_subtitle:               "Tous les sports. Tous les matchs. Tous les jours.",
        .paywall_weekly:                 "Hebdo",
        .paywall_monthly:                "Mensuel",
        .paywall_save_badge:             "-33 %",
        .paywall_best_value:             "MEILLEURE OFFRE",
        .paywall_compare_title:          "GRATUIT vs PRO",
        .paywall_compare_meta:           "CE QUE VOUS OBTENEZ",
        .paywall_faq_title:              "DES QUESTIONS ?",
        .paywall_faq_meta:               "FAQ",
        .paywall_fineprint_weekly:       "Essai gratuit de 7 jours, puis $14.99/semaine. L'abonnement se renouvelle automatiquement sauf annulation au moins 24 h avant la fin de la période. Les paiements sont traités via votre identifiant Apple.",
        .paywall_fineprint_monthly:      "Essai gratuit de 7 jours, puis $39.99/mois. L'abonnement se renouvelle automatiquement sauf annulation au moins 24 h avant la fin de la période. Les paiements sont traités via votre identifiant Apple.",
        .paywall_then_weekly:            "Puis $14.99/semaine · Annulez à tout moment",
        .paywall_then_monthly:           "Puis $39.99/mois · Annulez à tout moment",
        .paywall_cta_trial:              "Démarrer l'essai gratuit de 7 jours",
        .paywall_restore:                "Restaurer les achats",
        .paywall_terms:                  "Conditions d'utilisation",
        .paywall_privacy:                "Politique de confidentialité",
        .paywall_manage_subscription:    "Gérer l'abonnement",
        .paywall_skip:                   "Accès gratuit",
        .paywall_purchase_pending:       "Votre achat est en attente de validation. Nous débloquerons Pro dès qu'il sera confirmé.",

        // Cards
        .card_live:                      "EN DIRECT",
        .card_final:                     "TERMINÉ",
        .card_awaiting:                  "EN ATTENTE",
        .card_pending_grade:             "EN COURS D'ÉVALUATION",
        .card_vs:                        "VS",
        .card_ai_picks:                  "PICKS IA",
        .card_my_picks:                  "MES PICKS",
        .card_home_team:                 "DOM.",
        .card_away_team:                 "EXT.",
        .card_pick_label:                "IA",
        .card_lock_in:                   "VALIDER LE PICK IA",
        .card_save_pick:                 "Enregistrer le pick",
        .card_saved_toast:               "ENREGISTRÉ · CONFIANCE IA {n} %",

        // Bookmaker / age gate
        .bookmaker_sheet_title:          "PLACEZ VOTRE PICK",
        .bookmaker_disclaimer:           "Pick1 propose des prédictions IA à des fins de divertissement. Nous ne plaçons, n'acceptons et ne traitons aucun pari.",
        .bookmaker_gambler_hotline:      "Si vous ou un proche avez un problème de jeu, appelez le 1-800-GAMBLER.",
        .age_gate_title:                 "21 ANS ET PLUS",
        .age_gate_message:               "Pick1 propose des prédictions sportives par IA à des fins de divertissement. Les intégrations avec les opérateurs de paris exigent d'avoir 21 ans ou plus. En continuant, vous confirmez avoir l'âge légal pour parier dans votre juridiction.\n\nSi vous ou un proche avez un problème de jeu, appelez le 1-800-GAMBLER.",
        .age_gate_confirm:               "J'ai 21 ans ou plus",

        // Wins
        .wins_tab_title:                 "VICTOIRES",
        .wins_empty_title:               "Aucune victoire pour l'instant.",
        .wins_empty_sub:                 "Vos picks réglés et favoris s'afficheront ici.",

        // Live
        .live_tab_title:                 "EN DIRECT",
        .live_section_live:              "EN DIRECT",
        .live_section_awaiting:          "EN ATTENTE D'ÉVAL.",
        .live_section_final:             "TERMINÉS",
        .live_section_upcoming:          "À VENIR",
        .live_empty_title:               "Rien en direct pour le moment.",
        .live_empty_sub:                 "Revenez à l'approche du coup d'envoi.",
    ]
}
