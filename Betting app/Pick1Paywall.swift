// Pick1Paywall.swift
// Pro · All-Access paywall — implements the design from
// `Pick6 Account Pages.html` (Paywall · Weekly $14.99 / Monthly $39.99).
//
// Shown at the end of the onboarding flow, after the Success step. The
// CTA starts a 3-day free trial; the back button skips into the app.
//
// Layout:
//   Top nav (back + "APP · GO PRO" crumb)
//   Hero (kicker pill, "UNLOCK / EVERY PICK.", subtitle)
//   Weekly / Monthly toggle (with "SAVE 33%" badge)
//   Plan card with optional "Best Value" ribbon, price, feature list
//   FREE vs PRO comparison table
//   FAQ accordion
//   Fine print + Restore Purchases
//   Sticky bottom bar (CTA + then-pricing)

import SwiftUI
import StoreKit

enum PaywallPlan: String { case weekly, monthly }

private struct PlanCopy {
    let price: String
    let per: String
    let billed: String
    let equiv: String
}

private let planCopy: [PaywallPlan: PlanCopy] = [
    .weekly:  PlanCopy(price: "14.99", per: "/wk",
                       billed: "Billed weekly · Cancel anytime", equiv: "$2.14/day"),
    .monthly: PlanCopy(price: "39.99", per: "/mo",
                       billed: "Billed monthly · Best value",    equiv: "$9.99/week"),
]

struct OBPaywallScreen: View {
    let onBack: () -> Void
    let onSubscribe: (String) -> Void
    let onSkip: () -> Void

    @State private var plan: PaywallPlan = .monthly
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(LocalizationManager.self) private var loc
    @ObservedObject private var perf = PerformanceStats.shared

    /// Dismiss (✕) skip control reveals 5 seconds after the paywall opens
    /// (product decision 2026-07: long delays read as trapping; a quick out
    /// keeps trust while the value prop still gets first read). Kept
    /// deliberately quiet — a small ✕, not a labeled "Access Free" pill.
    @State private var skipUnlocked: Bool = false
    private let skipDelay: Double = 5.0

    /// Terms / Privacy sheets — required by App Review guideline 3.1.2
    /// to be reachable on the paywall itself, not just from Profile.
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            paywallTopNav
                .padding(.top, 8)
                .padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero.padding(.top, 8)
                    trackRecord.padding(.top, 18)
                    toggle.padding(.top, 18)
                    planCard.padding(.top, 14)
                    sectionHeading(title: "FREE vs PRO", meta: "WHAT YOU GET")
                    compareTable.padding(.top, 6)
                    sectionHeading(title: "QUESTIONS?", meta: "FAQ")
                        .padding(.top, 4)
                    faq.padding(.top, 6)
                    finePrint.padding(.top, 14)
                    legalLinks.padding(.top, 10)
                    restorePurchases.padding(.top, 4)
                    manageSubscriptions.padding(.top, 2)
                    Color.clear.frame(height: 28)
                }
            }
        }
        .sheet(isPresented: $showTerms) {
            LegalSheet(doc: .terms, isOpen: $showTerms)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalSheet(doc: .privacy, isOpen: $showPrivacy)
                .presentationDragIndicator(.visible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Screen-level dark canvas + a top-right lime glow that
            // bleeds across the hero. Putting the glow on the *screen*
            // (not on the hero VStack like before) gives it room to
            // wash a much larger area — the hero VStack was only ~200pt
            // tall, so the glow had nothing to bleed across before.
            ZStack {
                Color.p1Ink
                RadialGradient(
                    colors: [Color.p1Lime.opacity(0.42),
                             Color.p1Lime.opacity(0.18),
                             Color.p1Lime.opacity(0.04),
                             .clear],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: 260
                )
                .frame(width: 540, height: 540)
                .blur(radius: 60)
                .offset(x: 140, y: -180)
                .allowsHitTesting(false)
                // Subtle secondary glow at top-left for depth.
                RadialGradient(
                    colors: [Color.p1Lime.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(width: 380, height: 380)
                .blur(radius: 50)
                .offset(x: -120, y: -240)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyBar
        }
        .task { await perf.refresh() }
    }

    // MARK: - Top nav

    private var paywallTopNav: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.p1Foreground)
                    .frame(width: 38, height: 38)
                    .background(Color.p1Panel)
                    .overlay(Circle().stroke(Color.p1Line, lineWidth: 1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                Text("APP · ")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p1Mute)
                Text("GO PRO")
                    .font(.custom("BarlowCondensed-Black", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p1Foreground)
            }

            Spacer()

            // Right slot: 38pt placeholder until the 26s skip-delay elapses,
            // then fades in as a quiet ✕ that dismisses the paywall via
            // onSkip(). Subtle by design — present enough to satisfy App
            // Review's "must be dismissible" bar, but not an inviting CTA.
            ZStack {
                Color.clear.frame(width: 38, height: 38)
                if skipUnlocked {
                    Button(action: onSkip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.p1Mute)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(Color.p1Panel)
                                    .overlay(Circle().stroke(Color.p1Line, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
        }
        .padding(.horizontal, 18)
        .onAppear {
            Analytics.paywallViewed(source: "onboarding")
            // Reset on each presentation so the delay always plays.
            skipUnlocked = false
            DispatchQueue.main.asyncAfter(deadline: .now() + skipDelay) {
                withAnimation(.easeOut(duration: 0.35)) {
                    skipUnlocked = true
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.p1Lime)
                Text("PICK1 PRO")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p1Lime)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.p1Lime.opacity(0.12))
            .overlay(
                Capsule().stroke(Color.p1Lime.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
            .padding(.bottom, 14)

            OBTitle("UNLOCK", "EVERY ", emphasis: "PICK.", size: 64)

            Text("Full access to AI predictions across all sports, unlimited daily picks, deep analytics, and live game tracking.")
                .font(.system(size: 13))
                .foregroundColor(.p1Ink2)
                .lineSpacing(4)
                .padding(.top, 12)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        // No per-hero glow — the screen-level lime wash already
        // covers the full hero area with room to bleed.
    }

    // MARK: - Track record (social proof)

    /// Real, server-computed AI performance — the strongest conversion
    /// argument for a prediction app. Hidden until we have a meaningful
    /// sample so we never show a thin/embarrassing number.
    @ViewBuilder
    private var trackRecord: some View {
        if let s = perf.stats, s.total >= 20 {
            HStack(spacing: 0) {
                trackStat(value: "\(s.accuracy)%", label: loc.t(.paywall_track_accuracy))
                trackDivider
                trackStat(value: "\(s.wins)", label: loc.t(.paywall_track_wins))
                trackDivider
                trackStat(value: "\(s.total)", label: loc.t(.paywall_track_graded))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.p1Lime.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.p1Lime.opacity(0.28), lineWidth: 1)
                    )
            )
            .overlay(alignment: .top) {
                Text(loc.t(.paywall_track_kicker))
                    .font(.custom("BarlowCondensed-Bold", size: 9))
                    .kerning(2)
                    .foregroundColor(.p1LimeInk)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(Color.p1Lime))
                    .offset(y: -8)
            }
            .padding(.horizontal, 22)
        }
    }

    private func trackStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("BarlowCondensed-Black", size: 26))
                .foregroundColor(.p1Lime)
            Text(label)
                .font(.custom("BarlowCondensed-Bold", size: 9))
                .kerning(1.4)
                .foregroundColor(.p1Mute)
        }
        .frame(maxWidth: .infinity)
    }

    private var trackDivider: some View {
        Rectangle().fill(Color.p1Line).frame(width: 1, height: 28)
    }

    // MARK: - Plan toggle

    private var toggle: some View {
        HStack(spacing: 6) {
            toggleSegment(.weekly,
                          label: "Weekly", price: priceText(.weekly), per: "/wk",
                          showSave: false)
            toggleSegment(.monthly,
                          label: "Monthly", price: priceText(.monthly), per: "/mo",
                          showSave: true)
        }
        .padding(6)
        .background(Color.p1Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p1Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 22)
    }

    private func toggleSegment(
        _ p: PaywallPlan, label: String, price: String, per: String, showSave: Bool
    ) -> some View {
        let on = plan == p
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) { plan = p }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.custom("BarlowCondensed-Bold", size: 10))
                    .kerning(2)
                    .foregroundColor(on ? Color.p1Ink.opacity(0.55) : .p1Mute)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.custom("BarlowCondensed-Black", size: 22))
                        .foregroundColor(on ? .p1Ink : .p1Foreground)
                    Text(per)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(on ? Color.p1Ink.opacity(0.5) : .p1Mute)
                }

                if showSave {
                    Text("SAVE 33%")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .kerning(0.6)
                        .foregroundColor(on ? Color(hex: "#2D6") : Color(hex: "#4ADE80"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((on ? Color(hex: "#4ADE80").opacity(0.25)
                                       : Color(hex: "#4ADE80").opacity(0.14)))
                        .overlay(
                            Capsule().stroke(Color(hex: "#4ADE80").opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(on ? Color.p1Foreground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan card

    private var planCard: some View {
        let copy = planCopy[plan]!
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("PRO · ALL-ACCESS")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.2)
                    .foregroundColor(.p1Mute)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    // Full localized price incl. the storefront's own currency
                    // symbol ($, €, £, ¥ …) — never a hardcoded dollar sign.
                    Text(priceText(plan))
                        .font(.custom("BarlowCondensed-Black", size: 50))
                        .foregroundColor(.p1Foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(copy.per)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.p1Mute)
                        .padding(.leading, 4)
                }
                .padding(.top, 6)

                HStack(spacing: 4) {
                    Text(copy.equiv)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.p1Foreground)
                    Text("·").foregroundColor(.p1Mute)
                    Text(copy.billed)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.p1Ink2)
                }
                .padding(.top, 6)
                .padding(.bottom, 18)

                VStack(alignment: .leading, spacing: 10) {
                    feature(boldPrefix: "Unlimited AI picks", suffix: " across all 8 sports")
                    feature(boldPrefix: "Confidence scores & reasoning", suffix: " on every recommendation")
                    feature(boldPrefix: "Live game tracking", suffix: " with in-play updates")
                    feature(boldPrefix: "Full stats dashboard", suffix: " — track every pick over time")
                    feature(boldPrefix: "Deep matchup analysis", suffix: " · form, trends, key factors")
                    feature(boldPrefix: "Ad-free experience", suffix: " · Early access to new sports")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.p1Lime.opacity(0.08), Color.p1Panel],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.p1Lime.opacity(plan == .monthly ? 0.45 : 0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if plan == .monthly {
                bestValueRibbon
            }
        }
        .padding(.horizontal, 22)
    }

    private var bestValueRibbon: some View {
        Text("BEST VALUE")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .kerning(1.2)
            .foregroundColor(.p1LimeInk)
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
            .background(Color.p1Lime)
            .rotationEffect(.degrees(35))
            .offset(x: 28, y: 14)
            .clipped()
    }

    private func feature(boldPrefix: String, suffix: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.p1Lime.opacity(0.14))
                    .frame(width: 18, height: 18)
                Circle()
                    .stroke(Color.p1Lime, lineWidth: 1.2)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.p1Lime)
            }
            (Text(boldPrefix).fontWeight(.bold)
             + Text(suffix))
                .font(.system(size: 13))
                .foregroundColor(.p1Foreground)
                .lineSpacing(2)
        }
    }

    // MARK: - Compare table

    private struct CompareRow {
        let feature: String
        let free: String?    // nil → "—"
        let pro: String      // text or "✓"
        let proIsCheck: Bool
    }

    private let compareRows: [CompareRow] = [
        .init(feature: "AI recommendations",    free: "1 per sport/day", pro: "∞ Unlimited", proIsCheck: false),
        .init(feature: "Live game tracking",    free: nil,               pro: "✓",           proIsCheck: true),
        .init(feature: "Confidence scores",     free: "Partial",         pro: "Full",        proIsCheck: false),
        .init(feature: "Stats dashboard",       free: "7 days",          pro: "All-time",    proIsCheck: false),
        .init(feature: "Deep matchup analysis", free: nil,               pro: "✓",           proIsCheck: true),
        .init(feature: "Saved picks history",   free: nil,               pro: "✓",           proIsCheck: true),
        .init(feature: "Ad-free",               free: nil,               pro: "✓",           proIsCheck: true),
    ]

    private var compareTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("Feature")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FREE")
                    .frame(width: 70)
                    .foregroundColor(.p1Ink2)
                Text("PRO")
                    .frame(width: 70)
                    .foregroundColor(.p1Lime)
            }
            .font(.custom("BarlowCondensed-Bold", size: 10))
            .kerning(2)
            .foregroundColor(.p1Mute)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.p1Panel.opacity(0.5))

            // Rows
            ForEach(Array(compareRows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 10) {
                    Text(row.feature)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.p1Foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        if let free = row.free {
                            Text(free)
                                .foregroundColor(.p1Ink2)
                        } else {
                            Text("—").foregroundColor(.p1Mute)
                        }
                    }
                    .frame(width: 70)
                    .multilineTextAlignment(.center)

                    Group {
                        if row.proIsCheck {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .heavy))
                        } else {
                            Text(row.pro)
                        }
                    }
                    .foregroundColor(.p1Lime)
                    .frame(width: 70)
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if i < compareRows.count - 1 {
                    Rectangle().fill(Color.p1Line).frame(height: 1)
                }
            }
        }
        .background(Color.p1Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p1Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 22)
    }

    // MARK: - FAQ

    /// Localized FAQ, built from the active language. Trial wording is
    /// 3 days to match the actual introductory offer we sell.
    private var faqs: [PaywallFAQItem] {
        [
            .init(q: loc.t(.paywall_faq_q_cancel), a: loc.t(.paywall_faq_a_cancel)),
            .init(q: loc.t(.paywall_faq_q_trial),  a: loc.t(.paywall_faq_a_trial)),
            .init(q: loc.t(.paywall_faq_q_switch), a: loc.t(.paywall_faq_a_switch)),
        ]
    }

    private var faq: some View {
        VStack(spacing: 8) {
            ForEach(faqs.indices, id: \.self) { i in
                FAQRow(item: faqs[i])
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Section heading

    @ViewBuilder
    private func sectionHeading(title: String, meta: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.custom("BarlowCondensed-Black", size: 16))
                .kerning(0.6)
                .foregroundColor(.p1Foreground)
            Spacer()
            Text(meta)
                .font(.custom("BarlowCondensed-Bold", size: 10))
                .kerning(2)
                .foregroundColor(.p1Mute)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    // MARK: - Fine print + restore

    private var finePrint: some View {
        // App Review 3.1.2 requires the auto-renewal terms be disclosed
        // adjacent to the purchase action. Spell out:
        //   • Trial length + price-after-trial
        //   • Renewal terms (auto, cancel window)
        //   • That payment goes through Apple
        // Localized so the disclosure is honored in the user's language.
        let copy = String(format: loc.t(fineprintKey), priceText(plan))
        return Text(copy)
            .font(.system(size: 10))
            .foregroundColor(.p1Mute)
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
    }

    private var restorePurchases: some View {
        Button {
            Task { await subs.restorePurchases() }
        } label: {
            Text(loc.t(.paywall_restore))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.p1Ink2)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(subs.purchasing)
    }

    /// Terms of Service / Privacy Policy links — required by App Review
    /// guideline 3.1.2 adjacent to the auto-renewable subscription
    /// disclosure. Renders as two tappable links in a dot-separated row.
    private var legalLinks: some View {
        HStack(spacing: 14) {
            Button { showTerms = true } label: {
                Text(loc.t(.paywall_terms))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.p1Ink2)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("·").foregroundColor(.p1Mute)

            Button { showPrivacy = true } label: {
                Text(loc.t(.paywall_privacy))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.p1Ink2)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    /// "Manage Subscription" — deep-links into the iOS system sheet so
    /// the user can cancel / change tiers without leaving the app.
    /// Expected by App Review for any auto-renewing subscription app.
    private var manageSubscriptions: some View {
        Button {
            Task {
                if let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    try? await AppStore.showManageSubscriptions(in: scene)
                }
            }
        } label: {
            Text(loc.t(.paywall_manage_subscription))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.p1Mute)
                .underline()
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky CTA

    /// What the SUBSCRIBE NOW button should display + do right now.
    /// Driven off SubscriptionManager.productsLoadState so the button
    /// can never look "active" while products haven't loaded — that was
    /// the exact bug that got build 6 rejected ("unresponsive button").
    private enum CTAMode {
        case purchasing       // mid-purchase — spinner, disabled
        case loadingProducts  // products still being fetched — spinner + LOADING label
        case retry            // load failed or returned nothing — "TAP TO RETRY"
        case ready            // products loaded, can purchase
    }

    private var ctaMode: CTAMode {
        if subs.purchasing { return .purchasing }
        switch subs.productsLoadState {
        case .idle, .loading:
            return .loadingProducts
        case .failed:
            return .retry
        case .loaded:
            // Edge case: products loaded but none matches the selected
            // plan keyword. Still a retry path (re-fetching is the only
            // user-facing remedy).
            return selectedProduct == nil ? .retry : .ready
        }
    }

    private var stickyBar: some View {
        VStack(spacing: 8) {
            Button {
                Haptics.medium()
                triggerPurchase()
            } label: {
                Group {
                    switch ctaMode {
                    case .purchasing, .loadingProducts:
                        HStack(spacing: 10) {
                            ProgressView().tint(.p1LimeInk)
                            if ctaMode == .loadingProducts {
                                Text("LOADING…")
                                    .font(.custom("BarlowCondensed-Black", size: 15))
                                    .kerning(2.6)
                                    .foregroundColor(.p1LimeInk)
                            }
                        }
                    case .retry:
                        Text("TAP TO RETRY")
                            .font(.custom("BarlowCondensed-Black", size: 15))
                            .kerning(2.6)
                            .textCase(.uppercase)
                            .foregroundColor(.p1LimeInk)
                    case .ready:
                        // Only promise a free trial to an Apple ID that's
                        // still eligible for one. A returning user who
                        // already used theirs sees "Subscribe Now" — Apple
                        // won't grant a second trial regardless, so the CTA
                        // must not claim it would.
                        Text(loc.t(subs.introOfferEligible ? .paywall_cta_trial : .paywall_cta_subscribe))
                            .font(.custom("BarlowCondensed-Black", size: 15))
                            .kerning(2.6)
                            .textCase(.uppercase)
                            .foregroundColor(.p1LimeInk)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.p1Lime.opacity(ctaMode == .loadingProducts ? 0.55 : 1.0))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .pressableScale(0.97)
            }
            .buttonStyle(.plain)
            // Only fully-disabled while a purchase is in flight or
            // products are still loading. The .retry state is *intentionally*
            // tappable — that's the recovery path the reviewer needed.
            .disabled(ctaMode == .purchasing || ctaMode == .loadingProducts)
            // Success haptic the moment Apple confirms the purchase.
            .sensoryFeedback(.success, trigger: subs.isPro)

            captionUnderCTA
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [Color.p1Ink.opacity(0), Color.p1Ink.opacity(0.92), Color.p1Ink],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
        .onChange(of: subs.isPro) { _, nowPro in
            // The instant Apple confirms the purchase, dismiss the paywall.
            if nowPro { onSubscribe(plan.rawValue) }
        }
        .task {
            // Belt-and-suspenders: bootstrap() should have already loaded
            // products at launch, but if the user navigated here before
            // that finished — or if it failed — kick off a fresh attempt
            // so the CTA isn't stuck in .loading or .failed at first paint.
            if subs.productsLoadState == .idle
                || (subs.productsLoadState == .failed && subs.products.isEmpty) {
                await subs.loadProducts()
            }
        }
    }

    /// Caption below the CTA. Priorities, top → bottom:
    ///   1. A purchase error (most actionable feedback)
    ///   2. The load-error from `subs.lastLoadError` (explains the retry)
    ///   3. Default "then $X/period" pricing copy
    @ViewBuilder
    private var captionUnderCTA: some View {
        if let err = subs.lastError {
            Text(err)
                .font(.system(size: 11))
                .foregroundColor(.p1Hot)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        } else if ctaMode == .retry, let loadErr = subs.lastLoadError {
            Text(loadErr)
                .font(.system(size: 11))
                .foregroundColor(.p1Hot)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        } else {
            // Required subscription disclosure (App Review 3.1.2(c)): trial
            // length + price billed after trial + auto-renewal, shown clearly
            // and legibly right at the purchase action — not buried fine print.
            // Switches to no-trial wording once the trial's been used so we
            // never disclose a "3 days free" that Apple won't honor.
            Text(String(format: loc.t(thenKey), priceText(plan)))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.p1Ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    private var selectedProduct: Product? {
        let needle = plan == .weekly
            ? "weekly"
            : "monthly"
        return subs.products.first { $0.id.lowercased().contains(needle) }
    }

    /// The StoreKit product backing a plan (so we can read its localized price).
    private func product(for plan: PaywallPlan) -> Product? {
        let needle = plan == .weekly ? "weekly" : "monthly"
        return subs.products.first { $0.id.lowercased().contains(needle) }
    }

    /// Localized storefront price — "$14.99" in the US, "14,99 €" in France,
    /// "£11.99" in the UK, etc. StoreKit formats it for the user's region.
    /// Falls back to the hardcoded copy only until products finish loading.
    private func priceText(_ plan: PaywallPlan) -> String {
        product(for: plan)?.displayPrice ?? "$\(planCopy[plan]!.price)"
    }

    /// The "then …" disclosure key for the selected plan — trial wording
    /// while the Apple ID is still trial-eligible, no-trial wording once
    /// the single per-Apple-ID introductory offer has been consumed.
    private var thenKey: L10nKey {
        if subs.introOfferEligible {
            return plan == .weekly ? .paywall_then_weekly : .paywall_then_monthly
        } else {
            return plan == .weekly ? .paywall_then_weekly_notrial : .paywall_then_monthly_notrial
        }
    }

    /// Same trial / no-trial split for the longer 3.1.2 fine-print block.
    private var fineprintKey: L10nKey {
        if subs.introOfferEligible {
            return plan == .weekly ? .paywall_fineprint_weekly : .paywall_fineprint_monthly
        } else {
            return plan == .weekly ? .paywall_fineprint_weekly_notrial : .paywall_fineprint_monthly_notrial
        }
    }

    private func triggerPurchase() {
        switch ctaMode {
        case .purchasing, .loadingProducts:
            // Defensive — the button is disabled in these states, but
            // belt-and-suspenders in case a stale tap sneaks through.
            return

        case .retry:
            // Clear any stale purchase error so the user sees fresh
            // load-state feedback, then re-attempt the product load.
            subs.lastError = nil
            Task { await subs.reloadProducts() }
            return

        case .ready:
            guard let product = selectedProduct else {
                // selectedProduct can only be nil here in a race where
                // the plan toggle changed mid-tap and the matching
                // product hasn't been re-resolved. Trigger a reload
                // rather than dead-end the user.
                Task { await subs.reloadProducts() }
                return
            }
            Task { await subs.purchase(product) }
        }
    }
}

struct PaywallFAQItem {
    let q: String
    let a: String
}

// MARK: - FAQ row (custom expander)

private struct FAQRow: View {
    let item: PaywallFAQItem

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { open.toggle() }
            } label: {
                HStack {
                    Text(item.q)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.p1Foreground)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(open ? "−" : "+")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.p1Mute)
                        .frame(width: 18)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if open {
                Text(item.a)
                    .font(.system(size: 12))
                    .foregroundColor(.p1Ink2)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .background(open ? Color.p1Panel2 : Color.p1Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.p1Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
