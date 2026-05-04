// Pick6Paywall.swift
// Pro · All-Access paywall — implements the design from
// `Pick6 Account Pages.html` (Paywall · Weekly $14.99 / Monthly $39.99).
//
// Shown at the end of the onboarding flow, after the Success step. The
// CTA starts a 7-day free trial; the back button skips into the app.
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

    /// "Access Free" skip button reveals 7 seconds after the paywall opens.
    /// Lets users dismiss the paywall without subscribing — required for
    /// good UX (and several App Review precedents).
    @State private var skipUnlocked: Bool = false
    private let skipDelay: Double = 7.0

    var body: some View {
        VStack(spacing: 0) {
            paywallTopNav
                .padding(.top, 8)
                .padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero.padding(.top, 8)
                    toggle.padding(.top, 18)
                    planCard.padding(.top, 14)
                    sectionHeading(title: "FREE vs PRO", meta: "WHAT YOU GET")
                    compareTable.padding(.top, 6)
                    sectionHeading(title: "QUESTIONS?", meta: "FAQ")
                        .padding(.top, 4)
                    faq.padding(.top, 6)
                    finePrint.padding(.top, 14)
                    restorePurchases.padding(.top, 4)
                    Color.clear.frame(height: 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.p6Ink.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyBar
        }
    }

    // MARK: - Top nav

    private var paywallTopNav: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.p6Foreground)
                    .frame(width: 38, height: 38)
                    .background(Color.p6Panel)
                    .overlay(Circle().stroke(Color.p6Line, lineWidth: 1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 4) {
                Text("APP · ")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p6Mute)
                Text("GO PRO")
                    .font(.custom("BarlowCondensed-Black", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p6Foreground)
            }

            Spacer()

            // Right slot: 38pt placeholder until the 7s skip-delay elapses,
            // then fades in as an "Access Free" pill that dismisses the
            // paywall via onSkip().
            ZStack {
                Color.clear.frame(width: 96, height: 38)
                if skipUnlocked {
                    Button(action: onSkip) {
                        HStack(spacing: 4) {
                            Text("Access Free")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundColor(.p6Ink2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.p6Panel)
                                .overlay(Capsule().stroke(Color.p6Line, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
        }
        .padding(.horizontal, 18)
        .onAppear {
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
                    .foregroundColor(.p6Lime)
                Text("PICK6 PRO")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.4)
                    .foregroundColor(.p6Lime)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.p6Lime.opacity(0.12))
            .overlay(
                Capsule().stroke(Color.p6Lime.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
            .padding(.bottom, 14)

            OBTitle("UNLOCK", "EVERY ", emphasis: "PICK.", size: 64)

            Text("Full access to AI predictions across all sports, unlimited daily picks, deep analytics, and live game tracking.")
                .font(.system(size: 13))
                .foregroundColor(.p6Ink2)
                .lineSpacing(4)
                .padding(.top, 12)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .background(alignment: .topTrailing) {
            // Lime radial glow that washes the top-right of the
            // hero. The previous version clipped a small offset
            // circle behind .clipped(), which left the glow nearly
            // invisible — the bright center was off-canvas and only
            // a sliver of falloff was actually drawn. Now: a
            // 3-stop radial inside an explicit 380×320 frame, soft
            // 32pt blur, offset so the brightest point sits just
            // outside the trailing edge and the falloff bleeds
            // across the hero. No .clipped() — the glow naturally
            // fades to clear, so there's nothing to clip.
            RadialGradient(
                colors: [Color.p6Lime.opacity(0.35),
                         Color.p6Lime.opacity(0.08),
                         .clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: 220
            )
            .frame(width: 380, height: 320)
            .blur(radius: 32)
            .offset(x: 70, y: -90)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Plan toggle

    private var toggle: some View {
        HStack(spacing: 6) {
            toggleSegment(.weekly,
                          label: "Weekly", price: "$14.99", per: "/wk",
                          showSave: false)
            toggleSegment(.monthly,
                          label: "Monthly", price: "$39.99", per: "/mo",
                          showSave: true)
        }
        .padding(6)
        .background(Color.p6Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p6Line, lineWidth: 1)
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
                    .foregroundColor(on ? Color.p6Ink.opacity(0.55) : .p6Mute)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.custom("BarlowCondensed-Black", size: 22))
                        .foregroundColor(on ? .p6Ink : .p6Foreground)
                    Text(per)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(on ? Color.p6Ink.opacity(0.5) : .p6Mute)
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
            .background(on ? Color.p6Foreground : Color.clear)
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
                    .foregroundColor(.p6Mute)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$")
                        .font(.custom("BarlowCondensed-Black", size: 28))
                        .foregroundColor(.p6Ink2)
                    Text(copy.price)
                        .font(.custom("BarlowCondensed-Black", size: 54))
                        .foregroundColor(.p6Foreground)
                    Text(copy.per)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.p6Mute)
                        .padding(.leading, 4)
                }
                .padding(.top, 6)

                HStack(spacing: 4) {
                    Text(copy.equiv)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.p6Foreground)
                    Text("·").foregroundColor(.p6Mute)
                    Text(copy.billed)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.p6Ink2)
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
                    colors: [Color.p6Lime.opacity(0.08), Color.p6Panel],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.p6Lime.opacity(plan == .monthly ? 0.45 : 0.25), lineWidth: 1)
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
            .foregroundColor(.p6LimeInk)
            .padding(.horizontal, 28)
            .padding(.vertical, 4)
            .background(Color.p6Lime)
            .rotationEffect(.degrees(35))
            .offset(x: 28, y: 14)
            .clipped()
    }

    private func feature(boldPrefix: String, suffix: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.p6Lime.opacity(0.14))
                    .frame(width: 18, height: 18)
                Circle()
                    .stroke(Color.p6Lime, lineWidth: 1.2)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.p6Lime)
            }
            (Text(boldPrefix).fontWeight(.bold)
             + Text(suffix))
                .font(.system(size: 13))
                .foregroundColor(.p6Foreground)
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
                    .foregroundColor(.p6Ink2)
                Text("PRO")
                    .frame(width: 70)
                    .foregroundColor(.p6Lime)
            }
            .font(.custom("BarlowCondensed-Bold", size: 10))
            .kerning(2)
            .foregroundColor(.p6Mute)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.p6Panel.opacity(0.5))

            // Rows
            ForEach(Array(compareRows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 10) {
                    Text(row.feature)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.p6Foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        if let free = row.free {
                            Text(free)
                                .foregroundColor(.p6Ink2)
                        } else {
                            Text("—").foregroundColor(.p6Mute)
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
                    .foregroundColor(.p6Lime)
                    .frame(width: 70)
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if i < compareRows.count - 1 {
                    Rectangle().fill(Color.p6Line).frame(height: 1)
                }
            }
        }
        .background(Color.p6Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p6Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 22)
    }

    // MARK: - FAQ

    private let faqs: [PaywallFAQItem] = [
        .init(q: "Can I cancel anytime?",
              a: "Yes — cancel from Settings or the App Store at any time. You'll keep Pro access until the end of your billing period."),
        .init(q: "What's included in the 7-day trial?",
              a: "Full Pro access — unlimited picks, all sports, live tracking, full analytics. No charge until day 7. Cancel before then to avoid any charge."),
        .init(q: "Can I switch between weekly and monthly?",
              a: "Yes — switch plans at any time from Settings. The new rate takes effect on your next billing cycle."),
    ]

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
                .foregroundColor(.p6Foreground)
            Spacer()
            Text(meta)
                .font(.custom("BarlowCondensed-Bold", size: 10))
                .kerning(2)
                .foregroundColor(.p6Mute)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 6)
    }

    // MARK: - Fine print + restore

    private var finePrint: some View {
        Text("Subscription auto-renews unless canceled at least 24h before the period ends. Payments are processed through your App Store account.")
            .font(.system(size: 10))
            .foregroundColor(.p6Mute)
            .lineSpacing(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
    }

    private var restorePurchases: some View {
        Button {
            Task { await subs.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.p6Ink2)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(subs.purchasing)
    }

    // MARK: - Sticky CTA

    private var stickyBar: some View {
        VStack(spacing: 8) {
            Button(action: triggerPurchase) {
                Group {
                    if subs.purchasing {
                        ProgressView()
                            .tint(.p6LimeInk)
                    } else {
                        Text("Start 7-Day Free Trial")
                            .font(.custom("BarlowCondensed-Black", size: 15))
                            .kerning(2.6)
                            .textCase(.uppercase)
                            .foregroundColor(.p6LimeInk)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.p6Lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(subs.purchasing)

            if let err = subs.lastError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.p6Hot)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            } else {
                Text("Then \(plan == .weekly ? "$14.99/week" : "$39.99/month") · Cancel anytime")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.p6Mute)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [Color.p6Ink.opacity(0), Color.p6Ink.opacity(0.92), Color.p6Ink],
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
    }

    private var selectedProduct: Product? {
        let needle = plan == .weekly
            ? "weekly"
            : "monthly"
        return subs.products.first { $0.id.lowercased().contains(needle) }
    }

    private func triggerPurchase() {
        guard let product = selectedProduct else {
            subs.lastError = "Couldn't find that product. Make sure App Store Connect has \(SubscriptionManager.productIds.joined(separator: ", ")) configured."
            return
        }
        Task { await subs.purchase(product) }
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
                        .foregroundColor(.p6Foreground)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(open ? "−" : "+")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.p6Mute)
                        .frame(width: 18)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if open {
                Text(item.a)
                    .font(.system(size: 12))
                    .foregroundColor(.p6Ink2)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .background(open ? Color.p6Panel2 : Color.p6Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.p6Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

