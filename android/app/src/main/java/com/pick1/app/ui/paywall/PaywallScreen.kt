package com.pick1.app.ui.paywall

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.pick1.app.R
import com.pick1.app.billing.PlanOffer
import com.pick1.app.ui.components.FnlHeadline
import com.pick1.app.ui.theme.*
import kotlinx.coroutines.delay

/**
 * Paywall — port of `PaywallScreen` (Pick1OnboardingFunnel.swift).
 *
 * Deliberately matches iOS on the details that matter for App Review and
 * for conversion: the four feature checks, plan cards with BEST VALUE /
 * trial badges, restore + legal links, and the "continue free" escape that
 * fades in after 5s (the store listing promises a free tier, so the app is
 * never hard-gated).
 */
@Composable
fun PaywallScreen(
    plans: List<PlanOffer>,
    introEligible: Boolean,
    busy: Boolean = false,
    onBuy: (PlanOffer) -> Unit,
    onRestore: () -> Unit,
    onContinueFree: () -> Unit,
    /** The in-app upgrade prompt can be put away after a delay; the funnel
     *  paywall cannot. Hard paywall over freemium is the rule (2026-09-17). */
    allowSkip: Boolean = true,
) {
    // Weekly arrives selected: it is first in the list AND carries the badge
    // (weekly over monthly is the rule), so either way the flag decides.
    var selected by remember(plans) {
        mutableStateOf((plans.firstOrNull { it.isBestValue } ?: plans.firstOrNull())?.productId)
    }
    var skipUnlocked by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(5_000)          // same reveal delay as iOS (skipDelay = 5.0)
        skipUnlocked = true
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(P1.Ink)
            .safeDrawingPadding(),
    ) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
        ) {
            Spacer(Modifier.height(14.dp))
            Text(
                stringResource(R.string.funnel_paywall_kicker),
                style = archivoNarrow(11, FontWeight.Bold, tracking = 2.2f),
                color = P1.LimeFunnel,
            )
            Spacer(Modifier.height(14.dp))
            FnlHeadline(text = stringResource(R.string.funnel_paywall_headline), size = 40)
            Spacer(Modifier.height(12.dp))
            // Loss framing, not a feature list: what tonight costs without it.
            Text(
                stringResource(R.string.funnel_paywall_fomo),
                style = archivo(14),
                color = P1.Ink2,
            )

            Spacer(Modifier.height(18.dp))
            listOf(
                R.string.funnel_paywall_feat1,
                R.string.funnel_paywall_feat2,
                R.string.funnel_paywall_feat3,
                R.string.funnel_paywall_feat4,
            ).forEach { FeatureRow(stringResource(it)) }

            Spacer(Modifier.height(18.dp))
            if (plans.isEmpty()) {
                Text(
                    stringResource(R.string.funnel_paywall_loading),
                    style = archivo(13),
                    color = P1.Mute,
                    modifier = Modifier.padding(vertical = 20.dp),
                )
            } else {
                plans.forEach { p ->
                    PlanCard(
                        plan = p,
                        selected = selected == p.productId,
                        onSelect = { selected = p.productId },
                    )
                    Spacer(Modifier.height(10.dp))
                }
            }
            Spacer(Modifier.height(24.dp))
        }

        // ── Bottom CTA + legal ───────────────────────────────────────
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val chosen = plans.firstOrNull { it.productId == selected }
            // The CTA and the fine print quote the intro of the plan the user
            // is actually about to buy, not a global flag: eligibility is
            // per-product and quoting the wrong one is a pricing claim.
            val introPrice = chosen?.introPrice
            Text(
                when {
                    busy -> "…"
                    introPrice != null -> stringResource(R.string.funnel_paywall_cta_intro, introPrice)
                    else -> stringResource(R.string.funnel_paywall_cta_unlock)
                },
                style = anton(19),
                color = P1.LimeInk,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(P1.LimeFunnel)
                    .clickable(enabled = !busy && chosen != null) { chosen?.let(onBuy) }
                    .padding(vertical = 18.dp),
            )
            Spacer(Modifier.height(12.dp))
            Text(
                // Two placeholders on the intro line, as on iOS: the price
                // they pay now and the price it becomes. Stating only the
                // first would be the half of the sentence that sells.
                if (introPrice != null) {
                    stringResource(
                        R.string.funnel_paywall_fineprint_intro,
                        introPrice,
                        (chosen?.displayPrice ?: "") + (chosen?.unit ?: ""),
                    )
                } else {
                    stringResource(R.string.funnel_paywall_fineprint)
                },
                style = mono(11, FontWeight.Bold),
                color = P1.Mute,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                LinkText(stringResource(R.string.funnel_paywall_restore), onRestore)
                LinkText(stringResource(R.string.funnel_paywall_terms)) {}
                LinkText(stringResource(R.string.funnel_paywall_privacy)) {}
                if (allowSkip && skipUnlocked) {
                    Text(
                        stringResource(R.string.funnel_paywall_continue_free),
                        style = archivo(12, FontWeight.SemiBold),
                        color = P1.Ink2,
                        modifier = Modifier.clickable { onContinueFree() },
                    )
                }
            }
        }
    }
}

@Composable
private fun FeatureRow(text: String) {
    Row(
        Modifier.padding(vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(P1.LimeFunnel),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Check, null, tint = P1.Ink, modifier = Modifier.size(12.dp))
        }
        Text(text, style = archivo(14, FontWeight.Medium), color = P1.Foreground)
    }
}

/** One plan row — name/sub on the left, price on the right, badge on top. */
@Composable
private fun PlanCard(plan: PlanOffer, selected: Boolean, onSelect: () -> Unit) {
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(if (selected) P1.LimeFunnel.copy(alpha = 0.08f) else P1.Panel)
                .border(
                    if (selected) 2.dp else 1.dp,
                    if (selected) P1.LimeFunnel else P1.Line,
                    RoundedCornerShape(16.dp),
                )
                .clickable { onSelect() }
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(plan.name, style = anton(20), color = P1.Foreground)
                Text(plan.subtitle, style = archivo(12), color = P1.Ink2)
            }
            // Price, and under it the same-unit comparison. Stacked rather
            // than inline: "Économise 22,40 € par mois" is twice the width of
            // the English and would fight the price for the same row.
            Column(horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        plan.displayPrice,
                        style = anton(22),
                        color = if (selected) P1.LimeFunnel else P1.Foreground,
                    )
                    Text(plan.unit, style = archivo(12), color = P1.Ink2)
                }
                // The same figure for every plan, so the comparison is between
                // like and like, and on the cheapest one the difference spelled
                // out. Both come from the prices already on the card.
                plan.perMonth?.let {
                    Text(
                        "$it ${stringResource(R.string.paywall_per_month_suffix)}",
                        style = archivo(10),
                        color = P1.Ink2,
                    )
                } ?: plan.savingPerMonth?.let {
                    Text(
                        stringResource(R.string.paywall_saving_vs_other, it),
                        style = archivo(10, FontWeight.Bold),
                        color = P1.Win,
                    )
                }
            }
        }
        // MOST POPULAR sits on weekly, the plan the paywall leads with; the
        // other plans advertise the intro price instead.
        val badge = when {
            plan.isBestValue -> stringResource(R.string.funnel_paywall_most_popular) to P1.LimeFunnel
            plan.introPrice != null ->
                stringResource(R.string.funnel_paywall_intro_badge, plan.introPrice) to P1.Win
            else -> null
        }
        badge?.let { (label, bg) ->
            Text(
                label,
                style = archivoNarrow(9, FontWeight.Bold, tracking = 1.4f),
                color = P1.Ink,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = (-12).dp, y = (-8).dp)
                    .clip(CircleShape)
                    .background(bg)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
    }
}

@Composable
private fun LinkText(text: String, onClick: () -> Unit) {
    Text(
        text,
        style = archivo(12, FontWeight.SemiBold),
        color = P1.Mute,
        modifier = Modifier.clickable { onClick() },
    )
}
