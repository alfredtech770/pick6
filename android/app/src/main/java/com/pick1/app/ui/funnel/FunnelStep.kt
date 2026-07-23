package com.pick1.app.ui.funnel

/**
 * The 20-screen onboarding funnel — port of `FunnelStep`
 * (Pick1OnboardingFunnel.swift).
 *
 * Ordering note (kept identical to iOS): the quiz + analysis run BEFORE
 * account creation — the Cal-AI-style pattern. Users invest (answer
 * questions, watch their "analysis" build) before being asked to commit, so
 * sign-up reads as "save your results" rather than a cold gate at screen 3.
 * Everything after sign-up assumes a session.
 */
sealed class FunnelStep {
    data object Welcome : FunnelStep()
    data object Features : FunnelStep()
    data class Quiz(val index: Int) : FunnelStep()      // 0..4
    data object Analysis : FunnelStep()
    data object Signup : FunnelStep()
    data class Red(val index: Int) : FunnelStep()       // 0..3  hard truths
    data class Green(val index: Int) : FunnelStep()     // 0..2  the fix
    data object Social : FunnelStep()
    data object Compare : FunnelStep()
    data object Goals : FunnelStep()
    data object Notifications : FunnelStep()
    data object Referral : FunnelStep()
    data object Rating : FunnelStep()
    data object TimeToWin : FunnelStep()
    data object Paywall : FunnelStep()
    data object Success : FunnelStep()

    /** Analytics name — drives per-step events so drop-off is measurable. */
    val analyticsName: String
        get() = when (this) {
            Welcome -> "welcome"
            Features -> "features"
            is Quiz -> "quiz_${index + 1}"
            Analysis -> "analysis"
            Signup -> "signup"
            is Red -> "hard_truth_${index + 1}"
            is Green -> "fix_${index + 1}"
            Social -> "social_proof"
            Compare -> "compare"
            Goals -> "goals"
            Notifications -> "notifications"
            Referral -> "referral"
            Rating -> "rating"
            TimeToWin -> "time_to_win"
            Paywall -> "paywall"
            Success -> "success"
        }

    /** Whether the progress bar + back button show on this step. */
    val showsChrome: Boolean
        get() = this != Welcome && this != Success

    companion object {
        val ordered: List<FunnelStep> = buildList {
            add(Welcome); add(Features)
            addAll((0 until 5).map { Quiz(it) })
            add(Analysis); add(Signup)
            addAll((0 until 4).map { Red(it) })
            addAll((0 until 3).map { Green(it) })
            add(Social); add(Compare); add(Goals); add(Notifications)
            add(Referral); add(Rating); add(TimeToWin); add(Paywall); add(Success)
        }
    }
}
