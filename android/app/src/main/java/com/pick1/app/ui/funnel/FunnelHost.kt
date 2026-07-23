package com.pick1.app.ui.funnel

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.billing.PlaceholderCatalogue
import com.pick1.app.ui.paywall.PaywallScreen
import com.pick1.app.ui.theme.P1
import com.posthog.PostHog

/**
 * Drives the onboarding funnel: renders the current step, owns the progress
 * chrome, and records a per-step analytics event so drop-off is measurable
 * screen by screen — the same instrumentation the iOS funnel has.
 */
@Composable
fun FunnelHost(onFinished: () -> Unit) {
    var stepIndex by remember { mutableIntStateOf(0) }
    val steps = FunnelStep.ordered
    val step = steps[stepIndex]

    // Quiz + goal answers, persisted to echo the user's goal on the paywall.
    val quizAnswers = remember { mutableStateMapOf<Int, Int>() }
    var goal by remember { mutableStateOf<Int?>(null) }

    fun advance() {
        if (stepIndex < steps.lastIndex) stepIndex++ else onFinished()
    }
    fun back() {
        if (stepIndex > 0) stepIndex--
    }

    LaunchedEffect(stepIndex) {
        PostHog.capture("funnel_step_viewed", properties = mapOf("step" to step.analyticsName))
    }

    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        when (step) {
            FunnelStep.Welcome -> WelcomeScreen(onNext = ::advance, onSignIn = ::advance)
            FunnelStep.Features -> FeaturesScreen(onNext = ::advance)

            is FunnelStep.Quiz -> QuizScreen(
                index = step.index,
                selected = quizAnswers[step.index],
            ) { choice ->
                quizAnswers[step.index] = choice
                advance()
            }

            FunnelStep.Analysis -> AnalysisScreen(onDone = ::advance)

            // Sign-up sits after the analysis so it reads as "save your
            // results". Auth wiring lands with the Google Sign-In work.
            FunnelStep.Signup -> SimpleFunnelScreen(
                kick = R.string.funnel_signup_kicker,
                head = R.string.funnel_signup_headline,
                lead = null,
                cta = R.string.funnel_signup_cta_email,
                onNext = ::advance,
            )

            is FunnelStep.Red -> RedScreen(step.index, onNext = ::advance)
            is FunnelStep.Green -> GreenScreen(step.index, onNext = ::advance)

            FunnelStep.Social -> SimpleFunnelScreen(
                kick = R.string.funnel_social_kicker,
                head = R.string.funnel_social_headline,
                lead = null,
                cta = R.string.funnel_social_cta,
                onNext = ::advance,
            )

            FunnelStep.Compare -> SimpleFunnelScreen(
                kick = R.string.funnel_compare_kicker,
                head = R.string.funnel_compare_headline,
                lead = null,
                cta = R.string.funnel_continue_cta,
                onNext = ::advance,
            )

            FunnelStep.Goals -> GoalsScreen(selected = goal) { goal = it; advance() }

            FunnelStep.Notifications -> NotificationsScreen(
                onEnable = ::advance,   // runtime POST_NOTIFICATIONS prompt lands with FCM
                onSkip = ::advance,
            )

            FunnelStep.Referral -> SimpleFunnelScreen(
                kick = R.string.referral_title,
                head = R.string.referral_subtitle,
                lead = R.string.referral_have_code,
                cta = R.string.funnel_continue_cta,
                onNext = ::advance,
            )

            FunnelStep.Rating -> SimpleFunnelScreen(
                kick = R.string.funnel_rating_kicker,
                head = R.string.funnel_rating_headline,
                lead = R.string.funnel_rating_lead,
                cta = R.string.funnel_rating_cta,
                onNext = ::advance,
            )

            FunnelStep.TimeToWin -> SimpleFunnelScreen(
                kick = R.string.funnel_ttw_kicker,
                head = R.string.funnel_ttw_headline,
                lead = R.string.funnel_ttw_lead,
                cta = R.string.funnel_ttw_cta,
                onNext = ::advance,
            )

            FunnelStep.Paywall -> PaywallScreen(
                plans = PlaceholderCatalogue.plans(trialEligible = true),
                trialEligible = true,
                onBuy = { advance() },
                onRestore = { },
                onContinueFree = { advance() },
            )

            FunnelStep.Success -> SuccessScreen(onDone = onFinished)
        }

        // ── Chrome: progress bar + back ──────────────────────────────
        if (step.showsChrome) {
            Row(
                Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .safeDrawingPadding()
                    .padding(horizontal = 24.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.action_back),
                    tint = P1.Ink2,
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { back() },
                )
                FnlProgress(
                    progress = stepIndex.toFloat() / (steps.lastIndex).toFloat(),
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
