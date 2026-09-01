//  Pick1PaywallV2.swift
//  "Home v2 — Switch Style" paywall
//
//  A structural port of the mockup's `.pay` sheet: bolt mark, the "shows its
//  record" headline, the wins ticker, the three-stat proof strip, the feature
//  list, a review card, the offer timer, two plan rows, the shine button, and
//  the legal row.
//
//  Three places where the mockup could not be copied literally, each called
//  out at its use site:
//
//  1. PLANS. The mockup sells Annual $199.99 / Monthly $39.99. There is no
//     annual product in App Store Connect — Pick1 ships weekly, monthly,
//     lifetime and a day pass — so a literal copy would render a plan that
//     cannot be bought. The rows bind to StoreKit and the "Save %" badge is
//     computed from the real prices.
//  2. PROOF NUMBERS. "This season" is the app's real settled record. The
//     member count and store rating are NOT in any data source available here
//     — the unverifiable ones were removed 2026-08-24, see below.
//  3. THE TIMER. See `P1PayTimerV2`.

import SwiftUI
import StoreKit

// MARK: - Values with no data source

/// The two proof numbers and the review quote the mockup hard-codes. Nothing
/// in Supabase or StoreKit provides them, so they are declared here instead of
/// being scattered through the layout: this is the one place to correct before
/// the screen is ever shown outside the `-showPaywallV2` review flag.
///
/// Shipping unverified figures on a purchase screen is an App Store review
/// risk (2.3.1, deceptive) and cuts against Pick1's whole "we log the losses
/// too" position, which is the app's Meta-ads moat.
// REMOVED 2026-08-24, and deliberately not replaced.
//
// This screen used to carry a "4.9 ★ App Store" stat and a five-star quote
// attributed to "— App Store review". Neither was real. The rating was a
// number nobody had verified, and the quote was written for the mockup. The
// `reviews` table is no better as a source: all 8 rows share one insert
// timestamp to the microsecond, carry no email, IP or user agent, and
// describe a $39.99/mo plan and a daily 9am email that do not exist. They
// are seed data, not customers.
//
// Putting either in front of someone about to pay is deceptive, and App
// Review 2.3.1 covers it explicitly. The proof block below now shows only
// the app's own public record, which is real, already loaded, and is the
// actual argument Pick1 makes.

// MARK: - Wins ticker

/// The marquee under the headline. Fed by real settled picks, and it shows
/// losses as well as wins exactly as the mockup does — that mix is the point
/// of the "shows its record" headline, not an oversight.
struct P1WinsTickerV2: View {
    let picks: [Pick]

    private var items: [Pick] { Array(picks.filter { !$0.isPending }.prefix(7)) }

    var body: some View {
        if !items.isEmpty {
            TimelineView(.animation) { context in
                // 22s for one full loop of the doubled track, as in the CSS.
                let t = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 22) / 22
                GeometryReader { geo in
                    HStack(spacing: 26) {
                        ForEach(0..<2, id: \.self) { pass in
                            ForEach(items) { p in
                                tickerItem(p).id("\(pass)-\(p.id)")
                            }
                        }
                    }
                    .fixedSize()
                    .offset(x: -CGFloat(t) * geo.size.width)
                }
                .frame(height: 16)
            }
            .padding(.vertical, 9)
            .overlay(alignment: .top) { Rectangle().fill(Color.p1Line).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.p1Line).frame(height: 1) }
            .clipped()
            .padding(.top, 16)
        }
    }

    private func tickerItem(_ p: Pick) -> some View {
        // The raw pick text, not `shortDisplayPick` — the shortener takes the
        // last word of a club name, so "Sporting FC" came through the ticker
        // as a bare "FC".
        (
            Text("\(sportEmoji(p.sport)) \(p.pick) ")
                .foregroundStyle(Color.p1Ink2)
            + Text(p.isWin ? "✓ WON" : "✗ LOST")
                .foregroundStyle(p.isWin ? Color.p1Win : Color.p1Hot)
        )
        .font(.mono(11, weight: .bold))
        .lineLimit(1)
    }

    private func sportEmoji(_ sport: String) -> String {
        switch sport {
        case "basketball": return "🏀"; case "baseball": return "⚾️"
        case "hockey": return "🏒";     case "football": return "🏈"
        case "soccer": return "⚽️";     case "combat": return "🥊"
        case "f1": return "🏎️";         case "golf": return "⛳️"
        case "cricket": return "🏏";    case "tennis": return "🎾"
        default: return "🎯"
        }
    }
}

// MARK: - Proof strip

struct P1ProofStatV2: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.anton(17))
                .foregroundStyle(Color.p1Lime)
            Text(label.uppercased())
                .font(.archivoNarrow(8.5, weight: .bold))
                .tracking(1.02)                          // 0.12em at 8.5pt
                .foregroundStyle(Color.p1Mute)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feature row

struct P1FeatureRowV2: View {
    let text: String
    let note: String

    var body: some View {
        HStack(spacing: 11) {
            Text("✓")
                .font(.archivo(11, weight: .black))
                .foregroundStyle(Color.p1Lime)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.p1Lime.opacity(0.15)))
                .overlay(Circle().strokeBorder(Color.p1Lime.opacity(0.4), lineWidth: 1))
            Text(text)
                .font(.archivoNarrow(13, weight: .bold))
                .foregroundStyle(Color.p1Foreground)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(note.uppercased())
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Color.p1Mute)
        }
    }
}

// MARK: - Offer timer

/// The mockup's "Launch offer ends in 19:59".
///
/// A countdown that restarts on every appearance is fabricated urgency: App
/// Review treats it as deceptive, and it contradicts the honesty position the
/// headline right above it is selling. It is built here because the layout
/// calls for it, and it is driven by `deadline` so that pointing it at a real
/// offer window is a one-line change rather than a rewrite. Passing nil hides
/// the row entirely.
struct P1PayTimerV2: View {
    let deadline: Date?

    var body: some View {
        if let deadline {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, deadline.timeIntervalSince(context.date))
                HStack(spacing: 9) {
                    Text("⏱ LAUNCH OFFER ENDS IN")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "#FF9A80"))
                    Text(String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                        .font(.mono(15, weight: .bold))
                        .tracking(0.75)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Hot.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.p1Hot.opacity(0.45), lineWidth: 1))
            }
        }
    }
}

// MARK: - Plan row

struct P1PlanRowV2: View {
    let title: String
    let subtitle: String
    let price: String
    let unit: String
    let saveBadge: String?
    let isSelected: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.p1Lime : Color.p1Mute, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Color.p1Lime).frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.anton(16))
                        .foregroundStyle(Color.p1Foreground)
                    Text(subtitle)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(0.55)
                        .foregroundStyle(Color.p1Mute)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.anton(19))
                        .foregroundStyle(Color.p1Foreground)
                    Text(unit.uppercased())
                        .font(.archivoNarrow(9.5, weight: .bold))
                        .tracking(0.76)
                        .foregroundStyle(Color.p1Mute)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [Color.p1Lime.opacity(0.07), Color.p1Panel],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.p1Panel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.p1Lime : Color.p1Line, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if let saveBadge {
                    Text(saveBadge.uppercased())
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(Color.p1Ink)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Color.p1Lime))
                        .offset(x: -14, y: -10)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CTA

/// Lime pill with the mockup's diagonal shine sweeping across it every 3.6s.
struct P1PayButtonV2: View {
    let title: String
    var isBusy: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isBusy {
                    ProgressView().tint(Color.p1Ink)
                } else {
                    Text(title.uppercased())
                        .font(.anton(18))
                        .tracking(0.72)
                        .foregroundStyle(Color.p1Ink)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: [Color.p1Lime, Color(hex: "#A5D81F")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 3.6) / 3.6
                    GeometryReader { geo in
                        let travel = geo.size.width * 1.8
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.36)
                            .rotationEffect(.degrees(-18))
                            .offset(x: -geo.size.width * 0.6 + min(t / 0.55, 1) * travel)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(Capsule())
            .shadow(color: Color.p1Lime.opacity(0.3), radius: 17, y: 14)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

// MARK: - Screen

struct Pick1PaywallV2: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(\.openURL) private var openURL
    var onClose: () -> Void = {}

    @State private var selectedProductId: String?
    @State private var isPurchasing = false

    /// Weekly and monthly, in that order — the two auto-renewing plans a first
    /// purchase can pick between. Lifetime and the day pass are deliberately
    /// left out: the mockup shows exactly two rows.
    private var plans: [Product] {
        let wanted = ["com.pick1.app.pro.weekly", "com.pick1.app.pro.monthly"]
        return wanted.compactMap { id in subs.products.first { $0.id == id } }
    }

    private var selected: Product? {
        plans.first { $0.id == selectedProductId } ?? plans.last
    }

    /// Real saving of the monthly plan against paying weekly for a month
    /// (4.345 weeks). Nil unless both products loaded, so the badge never
    /// states a discount we have not actually computed.
    private var savePercent: Int? {
        guard let weekly = plans.first(where: { $0.id.hasSuffix("weekly") }),
              let monthly = plans.first(where: { $0.id.hasSuffix("monthly") }) else { return nil }
        let weeklyPerMonth = NSDecimalNumber(decimal: weekly.price).doubleValue * 4.345
        let monthlyPrice = NSDecimalNumber(decimal: monthly.price).doubleValue
        guard weeklyPerMonth > monthlyPrice, weeklyPerMonth > 0 else { return nil }
        return Int(((weeklyPerMonth - monthlyPrice) / weeklyPerMonth * 100).rounded())
    }

    private var settled: [Pick] { vm.historyPicks.filter { !$0.isPending } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color.p1Lime.opacity(0.14), Color.p1Ink],
                           startPoint: .top, endPoint: .center)
                .background(Color.p1Ink)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    P1BoltMark()
                        .fill(Color.p1LimeInk)
                        .frame(width: 52 * 0.6, height: 52 * 0.6)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle().fill(
                                LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        )
                        .shadow(color: Color.p1Lime.opacity(0.45), radius: 17)

                    (
                        Text("The AI that\nshows its ".uppercased())
                            .foregroundStyle(Color.p1Foreground)
                        + Text("record.".uppercased())
                            .foregroundStyle(Color.p1Lime)
                    )
                    .font(.anton(36))
                    .lineSpacing(-4)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                    Text(subheadline)
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.p1Ink2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    P1WinsTickerV2(picks: settled)
                        .padding(.horizontal, -22)      // full-bleed, as in the CSS

                    // Three real figures off the same settled history the
                    // ticker above is running on. Nothing here is a claim we
                    // cannot show the workings for.
                    HStack(spacing: 0) {
                        P1ProofStatV2(value: "\(vm.totalWins)/\(settled.count)", label: "This season")
                        Rectangle().fill(Color.p1Line).frame(width: 1, height: 26)
                        P1ProofStatV2(value: "\(Int(vm.winRate.rounded()))%", label: "Hit rate")
                        Rectangle().fill(Color.p1Line).frame(width: 1, height: 26)
                        P1ProofStatV2(value: "\(sportCount)", label: "Sports")
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))
                    .padding(.top, 16)

                    VStack(spacing: 9) {
                        P1FeatureRowV2(text: "Every market call, all \(sportCount) sports", note: "Free: 2")
                        P1FeatureRowV2(text: "Longshot of the day", note: "High return")
                        P1FeatureRowV2(text: "Tomorrow's pick the night before", note: "First access")
                        P1FeatureRowV2(text: "Full record · wins AND losses", note: "Logged")
                    }
                    .padding(.top, 16)


                    // nil until a real, server-defined offer window exists.
                    P1PayTimerV2(deadline: nil)

                    // Apple's own offer for this Apple ID, when there is
                    // one. Above the plans because it IS a plan choice, and
                    // the only one a returning subscriber should have to read.
                    if let wb = subs.bestWinBack {
                        P1WinBackBanner(product: wb.product, offer: wb.offer,
                                        isSelected: selected?.id == wb.product.id) {
                            Haptics.tap()
                            selectedProductId = wb.product.id
                        }
                        .padding(.top, 18)
                    }

                    VStack(spacing: 10) {
                        ForEach(plans, id: \.id) { product in
                            P1PlanRowV2(title: planTitle(product),
                                        subtitle: planSubtitle(product),
                                        price: product.displayPrice,
                                        unit: planUnit(product),
                                        saveBadge: badge(for: product),
                                        isSelected: product.id == selected?.id) {
                                selectedProductId = product.id
                            }
                        }
                    }
                    .padding(.top, 18)

                    if plans.isEmpty {
                        Text("Plans are still loading from the App Store.")
                            .font(.archivoNarrow(12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.p1Mute)
                            .padding(.top, 18)
                    }

                    P1PayButtonV2(title: ctaTitle, isBusy: isPurchasing) {
                        guard let product = selected else { return }
                        isPurchasing = true
                        Task {
                            // purchaseWithWinBack is deliberately a separate
                            // call: a win back offer is single use per
                            // customer, so it is spent only when the selected
                            // plan is the one Apple attached it to.
                            if let wb = subs.bestWinBack, wb.product.id == product.id {
                                await subs.purchaseWithWinBack(wb.product, offer: wb.offer)
                            } else {
                                await subs.purchase(product)
                            }
                            isPurchasing = false
                            if subs.isPro { onClose() }
                        }
                    }
                    .padding(.top, 18)
                    .disabled(selected == nil)
                    .opacity(selected == nil ? 0.5 : 1)

                    Text(payNote)
                        .font(.archivoNarrow(10, weight: .semibold))
                        .tracking(0.6)
                        .lineSpacing(6)
                        .foregroundStyle(Color.p1Mute)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    HStack(spacing: 16) {
                        legalLink("Terms", "https://pick1.live/terms")
                        legalLink("Privacy", "https://pick1.live/privacy")
                        Button {
                            Task { await subs.restorePurchases() }
                        } label: {
                            Text("RESTORE PURCHASE")
                                .font(.archivoNarrow(9.5, weight: .bold))
                                .tracking(0.76)
                                .foregroundStyle(Color.p1Mute)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    Color.clear.frame(height: 16)
                }
                .padding(.horizontal, 22)
                .padding(.top, 74)
            }

            Button(action: onClose) {
                Text("✕")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.p1Mute)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.p1Panel))
                    .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 66)
            .padding(.trailing, 20)
            .accessibilityLabel("Close")
        }
        .preferredColorScheme(.dark)
        .task {
            if subs.products.isEmpty { await subs.reloadProducts() }
            // Eligibility is per Apple ID and can change between launches, so
            // it is re-read here rather than trusted from app start.
            await subs.refreshWinBackOffers()
            selectedProductId = selectedProductId
                ?? subs.bestWinBack?.product.id
                ?? plans.last?.id
        }
    }

    // MARK: Copy

    /// The mockup's "3 days free" is only true of the monthly product, which
    /// is the one carrying an introductory offer — the weekly product has
    /// none. Saying it while weekly is selected would be a false claim on a
    /// purchase screen.
    private var hasFreeTrial: Bool {
        selected?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var subheadline: String {
        hasFreeTrial ? "3 days free · cancel anytime" : "Cancel anytime"
    }

    /// The offer, but only while the plan it belongs to is the selected one.
    /// Switching to the other plan drops it, and everything below follows.
    private var activeWinBack: (product: Product, offer: Product.SubscriptionOffer)? {
        guard let wb = subs.bestWinBack, wb.product.id == selected?.id else { return nil }
        return wb
    }

    private var ctaTitle: String {
        if activeWinBack != nil { return t(.wb_cta) }
        return hasFreeTrial ? "Start 3 days free" : "Continue"
    }

    private var payNote: String {
        guard let selected else { return "Predictions for entertainment · no wagering in app" }
        // With an offer applied the introductory-trial wording is wrong twice
        // over: the trial is not what is being granted, and the price after
        // it is not the price they land on.
        if let wb = activeWinBack {
            return P1WinBack.headline(wb.offer) + " · " + P1WinBack.afterwards(wb.product)
                + "\nPredictions for entertainment · no wagering in app"
        }
        let lead = hasFreeTrial
            ? "Then \(selected.displayPrice)\(planUnit(selected)) · cancel anytime in Settings"
            : "\(selected.displayPrice)\(planUnit(selected)) · cancel anytime in Settings"
        return lead + "\nPredictions for entertainment · no wagering in app"
    }

    private var sportCount: Int {
        max(Set(vm.todayPicks.map(\.sport)).count, Set(vm.historyPicks.map(\.sport)).count)
    }

    private func planTitle(_ p: Product) -> String {
        p.id.hasSuffix("weekly") ? "Weekly" : "Monthly"
    }

    private func planUnit(_ p: Product) -> String {
        p.id.hasSuffix("weekly") ? "/week" : "/month"
    }

    /// Per-day price, as the mockup's plan rows do ("$0.55/day"). Formatted
    /// through the product's own price style so it carries the storefront's
    /// currency — a bare "2.14/day" is meaningless outside the US.
    private func planSubtitle(_ p: Product) -> String {
        let days: Decimal = p.id.hasSuffix("weekly") ? 7 : 30
        let perDay = p.price / days
        return "\(perDay.formatted(p.priceFormatStyle))/day · cancel anytime"
    }

    private func badge(for p: Product) -> String? {
        guard p.id.hasSuffix("monthly"), let pct = savePercent else { return nil }
        return "Save \(pct)%"
    }

    private func legalLink(_ title: String, _ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            Text(title.uppercased())
                .font(.archivoNarrow(9.5, weight: .bold))
                .tracking(0.76)
                .foregroundStyle(Color.p1Mute)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
/// Reviewable on its own with `-showPaywallV2`.
struct Pick1PaywallV2DebugHost: View {
    @StateObject private var vm = PicksViewModel()

    var body: some View {
        Pick1PaywallV2(vm: vm)
            .task { await vm.loadAll() }
    }
}
#endif
