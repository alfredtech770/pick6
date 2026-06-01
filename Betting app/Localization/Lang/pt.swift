// Portuguese (Portugal) — manually translated from en.swift.
// Brand names, Pick1, USD currency stay verbatim.

enum PortugueseStrings {
    static let table: [L10nKey: String] = [

        // App / brand
        .app_name:                       "Pick1",
        .app_tagline:                    "Prognósticos desportivos com IA",
        .app_displayname_default:        "FÃ PICK1",

        // Bottom nav
        .nav_home:                       "Início",
        .nav_picks:                      "Prognósticos",
        .nav_live:                       "Em Direto",
        .nav_profile:                    "Perfil",
        .nav_live_count_singular:        "Jogos em direto, 1 a decorrer agora",
        .nav_live_count_plural:          "Jogos em direto, {n} a decorrer agora",

        // Generic actions
        .action_done:                    "Concluído",
        .action_cancel:                  "Cancelar",
        .action_continue:                "Continuar",
        .action_back:                    "Voltar",
        .action_close:                   "Fechar",
        .action_save:                    "Guardar",
        .action_edit:                    "Editar",
        .action_delete:                  "Eliminar",
        .action_confirm:                 "Confirmar",
        .action_retry:                   "Tentar novamente",
        .action_skip:                    "Ignorar",
        .action_next:                    "Seguinte",
        .action_share:                   "Partilhar",

        // State / errors
        .state_loading:                  "A carregar…",
        .state_no_picks_today:           "Sem prognósticos hoje.",
        .state_offline_title:            "Não foi possível contactar a Pick1",
        .state_offline_body:             "Verifica a tua ligação e tenta novamente.",
        .error_generic:                  "Algo correu mal. Por favor, tenta novamente.",
        .error_network:                  "Não foi possível contactar o servidor Pick1. Verifica a tua ligação e tenta novamente.",

        // Auth
        .auth_welcome_title:             "Iniciar sessão",
        .auth_welcome_sub:               "Picks de IA em todos os desportos. Faz escolhas mais inteligentes.",
        .auth_apple_button:              "Iniciar sessão com a Apple",
        .auth_or_divider:                "OU",
        .auth_email_placeholder:         "Endereço de email",
        .auth_send_code:                 "Envia-me um código por email",
        .auth_code_title:                "Introduz o teu código",
        .auth_code_sub:                  "Enviámos um código de 6 dígitos para o teu email.",
        .auth_code_placeholder:          "Código de 6 dígitos",
        .auth_code_verify:               "Verificar",
        .auth_code_resend:               "Reenviar código",
        .auth_must_be_21:                "Tens de ter 21+ para usar a Pick1",
        .auth_terms_disclaimer:          "Ao continuar, concordas com os nossos Termos de Serviço e Política de Privacidade.",

        // Settings
        .settings_account_section:       "CONTA",
        .settings_prefs_meta:            "PREFERÊNCIAS",
        .settings_notifications:         "Notificações",
        .settings_notifications_sub:     "Jogos em direto · prognósticos · resultados",
        .settings_language:              "Idioma",
        .settings_language_sub_default:  "Predefinição do sistema",
        .settings_subscription:          "Subscrição",
        .settings_subscription_free:     "GRÁTIS",
        .settings_subscription_pro:      "PRO",
        .settings_subscription_sub_pro:  "Gerir nas Definições do iOS",
        .settings_subscription_sub_free: "Desbloqueia todos os picks · passa a Pro",
        .settings_support_section:       "APOIO",
        .settings_help_meta:             "AJUDA",
        .settings_help_center:           "Centro de ajuda",
        .settings_privacy_security:      "Privacidade e Segurança",
        .settings_terms:                 "Termos de Serviço",
        .settings_privacy_policy:        "Política de Privacidade",
        .settings_sign_out:              "Terminar Sessão",
        .settings_app_version:           "Versão da aplicação",

        // Edit profile
        .profile_edit_title:             "Editar perfil",
        .profile_first_name:             "Nome próprio",
        .profile_last_name:              "Apelido",
        .profile_whatsapp:               "WhatsApp",
        .profile_dob:                    "Data de nascimento",
        .profile_delete_account:         "Eliminar Conta",
        .profile_delete_alert_title:     "Eliminar conta?",
        .profile_delete_alert_message:   "Isto elimina permanentemente a tua conta Pick1 e o histórico de prognósticos no prazo de 30 dias. As subscrições ativas têm de ser canceladas separadamente nas Definições do iOS → Subscrições.",
        .profile_delete_alert_confirm:   "Eliminar",

        // Language picker
        .lang_picker_title:              "IDIOMA",

        // Paywall
        .paywall_kicker:                 "PASSA A PRO",
        .paywall_title:                  "Desbloqueia todos os picks.",
        .paywall_subtitle:               "Todos os desportos. Todos os jogos. Todos os dias.",
        .paywall_weekly:                 "Semanal",
        .paywall_monthly:                "Mensal",
        .paywall_save_badge:             "POUPA 33%",
        .paywall_best_value:             "MELHOR VALOR",
        .paywall_compare_title:          "GRÁTIS vs PRO",
        .paywall_compare_meta:           "O QUE RECEBES",
        .paywall_faq_title:              "DÚVIDAS?",
        .paywall_faq_meta:               "FAQ",
        .paywall_fineprint_weekly:       "$14.99/semana. A subscrição renova-se automaticamente, salvo se for cancelada pelo menos 24h antes do fim do período. Os pagamentos são processados através do teu Apple ID.",
        .paywall_fineprint_monthly:      "7 dias de avaliação gratuita, depois $39.99/mês. A subscrição renova-se automaticamente, salvo se for cancelada pelo menos 24h antes do fim do período. Os pagamentos são processados através do teu Apple ID.",
        .paywall_then_weekly:            "$14.99/semana · Cancela quando quiseres",
        .paywall_then_monthly:           "Depois $39.99/mês · Cancela quando quiseres",
        .paywall_cta_trial:              "Começar Avaliação Gratuita de 7 Dias",
        .paywall_cta_subscribe:          "Subscrever agora",
        .paywall_restore:                "Restaurar Compras",
        .paywall_terms:                  "Termos de Serviço",
        .paywall_privacy:                "Política de Privacidade",
        .paywall_manage_subscription:    "Gerir Subscrição",
        .paywall_skip:                   "Aceder Grátis",
        .paywall_purchase_pending:       "A tua compra está pendente de aprovação. Vamos desbloquear o Pro assim que for validada.",

        // Cards
        .card_live:                      "EM DIRETO",
        .card_final:                     "FINAL",
        .card_awaiting:                  "À ESPERA",
        .card_pending_grade:             "POR AVALIAR",
        .card_vs:                        "VS",
        .card_ai_picks:                  "PICKS IA",
        .card_my_picks:                  "OS MEUS PICKS",
        .card_home_team:                 "CASA",
        .card_away_team:                 "FORA",
        .card_pick_label:                "IA",
        .card_save_pick:                 "Guardar pick",
        .card_saved_toast:               "GUARDADO · {n}% CONFIANÇA IA",

        // Age gate
        .age_gate_title:                 "APENAS 18+",
        .age_gate_message:               "A Pick1 apresenta prognósticos desportivos de IA para entretenimento — estimativas estatísticas, não garantias. Ao continuar, confirmas que tens 18 anos ou mais.",
        .age_gate_confirm:               "Tenho 18 anos ou mais",

        // Wins
        .wins_tab_title:                 "VITÓRIAS",
        .wins_empty_title:               "Ainda sem vitórias.",
        .wins_empty_sub:                 "Os picks resolvidos e favoritos vão aparecer aqui.",

        // Live
        .live_tab_title:                 "EM DIRETO",
        .live_section_live:              "AGORA EM DIRETO",
        .live_section_awaiting:          "POR AVALIAR",
        .live_section_final:             "FINAL",
        .live_section_upcoming:          "PRÓXIMOS",
        .live_empty_title:               "Nada em direto agora.",
        .live_empty_sub:                 "Volta mais perto do apito inicial.",
    ]
}
