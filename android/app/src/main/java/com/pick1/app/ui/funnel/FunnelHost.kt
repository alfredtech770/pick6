package com.pick1.app.ui.funnel

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import android.app.Activity
import com.pick1.app.R
import com.pick1.app.billing.Billing
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

    // Live Play Billing state for the paywall step.
    val ctx = LocalContext.current
    val activity = ctx as? Activity
    val offers by Billing.offers.collectAsState()
    val trialEligible by Billing.trialEligible.collectAsState()
    val isPro by Billing.isPro.collectAsState()

    LaunchedEffect(stepIndex) {
        PostHog.capture("funnel_step_viewed", properties = mapOf("step" to step.analyticsName))
    }

    // A successful purchase on the paywall step advances to Success.
    LaunchedEffect(isPro, step) {
        if (isPro && step == FunnelStep.Paywall) advance()
    }

    Box(Modifier.fillMaxSize().background(P1.Ink)) {
        // Apple-style push. The funnel moved both screens the same distance,
        // which reads as two slides passing each other. The incoming screen
        // now travels the full width while the outgoing one drifts a third of
        // the way out and fades. That mismatch is what every push does and it
        // is the whole reason a push reads as depth.
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                val forward = steps.indexOf(targetState) >= steps.indexOf(initialState)
                val enter = slideInHorizontally(tween(440)) { w -> if (forward) w else -w }
                val exit = slideOutHorizontally(tween(440)) { w ->
                    if (forward) -w / 3 else w / 3
                } + fadeOut(tween(440))
                (enter togetherWith exit).using(SizeTransform(clip = false))
            },
            label = "funnel",
        ) { step ->
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
            // results" rather than a cold registration wall.
            FunnelStep.Signup -> SignupScreen(onNext = ::advance)

            is FunnelStep.Red -> RedScreen(step.index, onNext = ::advance)
            is FunnelStep.Green -> GreenScreenRich(step.index, onNext = ::advance)

            FunnelStep.Social -> SocialProofScreen(onNext = ::advance)

            FunnelStep.Compare -> CompareScreen(onNext = ::advance)

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
                plans = offers.ifEmpty { PlaceholderCatalogue.plans(trialEligible) },
                trialEligible = trialEligible,
                onBuy = { plan -> activity?.let { Billing.purchase(it, plan.productId) } },
                onRestore = { Billing.restore() },
                onContinueFree = { advance() },
            )

            FunnelStep.Success -> SuccessScreen(onDone = onFinished)
        }
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
