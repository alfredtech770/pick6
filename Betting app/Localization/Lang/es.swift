// Spanish (Castilian) — manually translated from en.swift.
// Brand names, Pick1, USD currency stay verbatim.

enum SpanishStrings {
    static let table: [L10nKey: String] = [

        // App / brand
        .app_name:                       "Pick1",
        .app_tagline:                    "Predicciones deportivas con IA",
        .app_displayname_default:        "FAN DE PICK1",

        // Bottom nav
        .nav_home:                       "Inicio",
        .nav_picks:                      "Picks",
        .nav_live:                       "En vivo",
        .nav_profile:                    "Perfil",
        .nav_live_count_singular:        "Partidos en vivo, 1 en juego ahora",
        .nav_live_count_plural:          "Partidos en vivo, {n} en juego ahora",

        // Generic actions
        .action_done:                    "Hecho",
        .action_cancel:                  "Cancelar",
        .action_continue:                "Continuar",
        .action_back:                    "Atrás",
        .action_close:                   "Cerrar",
        .action_save:                    "Guardar",
        .action_edit:                    "Editar",
        .action_delete:                  "Eliminar",
        .action_confirm:                 "Confirmar",
        .action_retry:                   "Reintentar",
        .action_skip:                    "Omitir",
        .action_next:                    "Siguiente",
        .action_share:                   "Compartir",

        // State / errors
        .state_loading:                  "Cargando…",
        .state_no_picks_today:           "No hay picks hoy.",
        .state_offline_title:            "No se pudo conectar con Pick1",
        .state_offline_body:             "Comprueba tu conexión e inténtalo de nuevo.",
        .error_generic:                  "Algo ha ido mal. Inténtalo de nuevo.",
        .error_network:                  "No se pudo conectar con el servidor de Pick1. Comprueba tu conexión e inténtalo de nuevo.",

        // Auth
        .auth_welcome_title:             "Iniciar sesión",
        .auth_welcome_sub:               "Picks con IA en todos los deportes. Acierta más.",
        .auth_apple_button:              "Iniciar sesión con Apple",
        .auth_or_divider:                "O",
        .auth_email_placeholder:         "Correo electrónico",
        .auth_send_code:                 "Enviarme un código",
        .auth_code_title:                "Introduce tu código",
        .auth_code_sub:                  "Te hemos enviado un código de 6 dígitos a tu correo.",
        .auth_code_placeholder:          "Código de 6 dígitos",
        .auth_code_verify:               "Verificar",
        .auth_code_resend:               "Reenviar código",
        .auth_must_be_21:                "Debes tener 21 años o más para usar Pick1",
        .auth_terms_disclaimer:          "Al continuar aceptas nuestros Términos del servicio y la Política de privacidad.",

        // Settings
        .settings_account_section:       "CUENTA",
        .settings_prefs_meta:            "PREFERENCIAS",
        .settings_notifications:         "Notificaciones",
        .settings_notifications_sub:     "Partidos en vivo · picks · resultados",
        .settings_language:              "Idioma",
        .settings_language_sub_default:  "Predeterminado del sistema",
        .settings_subscription:          "Suscripción",
        .settings_subscription_free:     "GRATIS",
        .settings_subscription_pro:      "PRO",
        .settings_subscription_sub_pro:  "Gestionar en Ajustes de iOS",
        .settings_subscription_sub_free: "Desbloquea todos los picks · hazte Pro",
        .settings_support_section:       "SOPORTE",
        .settings_help_meta:             "AYUDA",
        .settings_help_center:           "Centro de ayuda",
        .settings_privacy_security:      "Privacidad y seguridad",
        .settings_terms:                 "Términos del servicio",
        .settings_privacy_policy:        "Política de privacidad",
        .settings_sign_out:              "Cerrar sesión",
        .settings_app_version:           "Versión de la app",

        // Edit profile
        .profile_edit_title:             "Editar perfil",
        .profile_first_name:             "Nombre",
        .profile_last_name:              "Apellidos",
        .profile_whatsapp:               "WhatsApp",
        .profile_dob:                    "Fecha de nacimiento",
        .profile_delete_account:         "Eliminar cuenta",
        .profile_delete_alert_title:     "¿Eliminar cuenta?",
        .profile_delete_alert_message:   "Esto eliminará permanentemente tu cuenta de Pick1 y tu historial de picks en un plazo de 30 días. Las suscripciones activas deben cancelarse por separado en Ajustes de iOS → Suscripciones.",
        .profile_delete_alert_confirm:   "Eliminar",

        // Language picker
        .lang_picker_title:              "IDIOMA",

        // Paywall
        .paywall_kicker:                 "HAZTE PRO",
        .paywall_title:                  "Desbloquea todos los picks.",
        .paywall_subtitle:               "Todos los deportes. Todos los partidos. Todos los días.",
        .paywall_weekly:                 "Semanal",
        .paywall_monthly:                "Mensual",
        .paywall_save_badge:             "AHORRA 33%",
        .paywall_best_value:             "MEJOR OPCIÓN",
        .paywall_compare_title:          "GRATIS vs PRO",
        .paywall_compare_meta:           "QUÉ INCLUYE",
        .paywall_faq_title:              "¿DUDAS?",
        .paywall_faq_meta:               "FAQ",
        .paywall_fineprint_weekly:       "Prueba gratuita de 7 días, después $14.99/semana. La suscripción se renueva automáticamente salvo que se cancele al menos 24 h antes del fin del periodo. Los pagos se procesan a través de tu ID de Apple.",
        .paywall_fineprint_monthly:      "Prueba gratuita de 7 días, después $39.99/mes. La suscripción se renueva automáticamente salvo que se cancele al menos 24 h antes del fin del periodo. Los pagos se procesan a través de tu ID de Apple.",
        .paywall_then_weekly:            "Después $14.99/semana · Cancela cuando quieras",
        .paywall_then_monthly:           "Después $39.99/mes · Cancela cuando quieras",
        .paywall_cta_trial:              "Empezar prueba gratis de 7 días",
        .paywall_restore:                "Restaurar compras",
        .paywall_terms:                  "Términos del servicio",
        .paywall_privacy:                "Política de privacidad",
        .paywall_manage_subscription:    "Gestionar suscripción",
        .paywall_skip:                   "Acceso gratis",
        .paywall_purchase_pending:       "Tu compra está pendiente de aprobación. Activaremos Pro en cuanto se confirme.",

        // Cards
        .card_live:                      "EN VIVO",
        .card_final:                     "FINAL",
        .card_awaiting:                  "PENDIENTE",
        .card_pending_grade:             "SIN CALIFICAR",
        .card_vs:                        "VS",
        .card_ai_picks:                  "PICKS IA",
        .card_my_picks:                  "MIS PICKS",
        .card_home_team:                 "LOCAL",
        .card_away_team:                 "VISITANTE",
        .card_pick_label:                "IA",
        .card_lock_in:                   "FIJAR PICK IA",
        .card_save_pick:                 "Guardar pick",
        .card_saved_toast:               "GUARDADO · {n}% CONFIANZA IA",

        // Bookmaker / age gate
        .bookmaker_sheet_title:          "HAZ TU PICK",
        .bookmaker_disclaimer:           "Pick1 muestra predicciones de IA con fines de entretenimiento. No realizamos, aceptamos ni procesamos apuestas.",
        .bookmaker_gambler_hotline:      "Si tú o alguien que conoces tiene un problema con el juego, llama al 1-800-GAMBLER.",
        .age_gate_title:                 "SOLO +21",
        .age_gate_message:               "Pick1 muestra predicciones deportivas con IA con fines de entretenimiento. Las integraciones con casas de apuestas requieren tener 21 años o más. Al continuar confirmas que cumples la edad legal para apostar en tu jurisdicción.\n\nSi tú o alguien que conoces tiene un problema con el juego, llama al 1-800-GAMBLER.",
        .age_gate_confirm:               "Tengo 21 años o más",

        // Wins
        .wins_tab_title:                 "VICTORIAS",
        .wins_empty_title:               "Aún no hay victorias.",
        .wins_empty_sub:                 "Los picks resueltos y favoritos aparecerán aquí.",

        // Live
        .live_tab_title:                 "EN VIVO",
        .live_section_live:              "EN VIVO AHORA",
        .live_section_awaiting:          "PENDIENTE DE CALIFICAR",
        .live_section_final:             "FINAL",
        .live_section_upcoming:          "PRÓXIMOS",
        .live_empty_title:               "Nada en vivo ahora mismo.",
        .live_empty_sub:                 "Vuelve más cerca del inicio.",
    ]
}
