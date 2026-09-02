//  Pick1WinBackOffer.swift
//  The paywall's win back offer surface.
//
//  WHY THIS EXISTS, AND WHY IT IS NOT Pick1WinBackV2.
//
//  `Pick1WinBackV2` is a mockup port sitting behind the `-showWinBackV2`
//  debug flag. It advertises "Claim 50% off" over a struck through price and
//  a countdown, and its button buys the plan at FULL PRICE, because no such
//  offer has ever existed. It also lists only the winning calls the lapsed
//  user missed. Both are the opposite of the argument Pick1 makes, and either
//  one shipped would be an App Review 2.3.1 problem. It is deliberately not
//  wired to anything and this file replaces it.
//
//  What this renders instead is whatever Apple actually says the customer is
//  eligible for. `Product.SubscriptionInfo.winBackOffers` is filtered by
//  StoreKit to the calling Apple ID, so a non empty result means "Apple will
//  honour this at checkout", and an empty one means "not eligible" rather
//  than "none configured". Every number below comes off the offer itself, so
//  the banner cannot describe terms the App Store will not grant, and it
//  disappears on its own the moment the offer is spent or withdrawn.
//
//  THE PERIOD TEXT is built by DateComponentsFormatter against the app's own
//  language choice rather than a table of hand written strings. "1 month" /
//  "1 mois" / "3 meses" and their plurals come out correct in all seven
//  languages with nothing to maintain and nothing to get wrong.

import SwiftUI
import StoreKit

// MARK: - Offer wording

enum P1WinBack {

    /// A subscription period as a phrase, in the language the user picked in
    /// Profile, not the device language.
    static func periodText(_ p: Product.SubscriptionPeriod, times: Int = 1) -> String {
        periodText(unit: p.unit, value: p.value, times: times)
    }

    /// The same, from the parts. `Product.SubscriptionPeriod` has no public
    /// initialiser, so this is what the review host can call.
    static func periodText(unit: Product.SubscriptionPeriod.Unit,
                           value: Int, times: Int = 1) -> String {
        var dc = DateComponents()
        let n = value * max(times, 1)
        switch unit {
        case .day:   dc.day = n
        case .week:  dc.weekOfMonth = n
        case .month: dc.month = n
        case .year:  dc.year = n
        @unknown default: dc.day = n
        }
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.day, .weekOfMonth, .month, .year]
        f.maximumUnitCount = 1
        var cal = Calendar(identifier: .gregorian)
        cal.locale = LocalizationManager.shared.displayLocale
        f.calendar = cal
        return f.string(from: dc) ?? "\(n)"
    }

    /// A period unit as a bare noun ("month", "mois"), for the phrases where
    /// a leading "1" reads wrong: "per 1 month", "$39.99 / 1 month".
    @MainActor
    static func unitText(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:   return t(.wb_unit_day)
        case .week:  return t(.wb_unit_week)
        case .month: return t(.wb_unit_month)
        case .year:  return t(.wb_unit_year)
        @unknown default: return t(.wb_unit_month)
        }
    }

    /// The headline terms, read straight off the offer.
    ///
    /// Three payment modes, three honest sentences. `paymentMode` is the only
    /// thing that decides which, so an offer changed in App Store Connect
    /// changes this text without a build.
    @MainActor
    static func headline(_ offer: Product.SubscriptionOffer) -> String {
        switch offer.paymentMode {
        case .freeTrial:
            return String(format: t(.wb_free), periodText(offer.period))
        case .payUpFront:
            return String(format: t(.wb_for), offer.displayPrice,
                          periodText(offer.period, times: offer.periodCount))
        case .payAsYouGo:
            // "$19.99 per month for 3 months": the recurring unit as a noun,
            // then the full span, so the customer reads both what is charged
            // each time and how long it lasts.
            return String(format: t(.wb_each_for), offer.displayPrice,
                          unitText(offer.period.unit),
                          periodText(offer.period, times: offer.periodCount))
        default:
            // An unknown mode is possible on a future OS. Say what is certain
            // (there is an offer) rather than inventing terms for it.
            return t(.wb_badge)
        }
    }

    /// What happens when the offer runs out. Always shown, because the price
    /// the customer lands on is the part an offer banner is most tempted to
    /// leave out.
    @MainActor
    static func afterwards(_ product: Product) -> String {
        // A plan whose period is a single unit reads as "$39.99 / month"; a
        // multi-unit one keeps its count, as "$199.99 / 12 months" must.
        let unit: String? = product.subscription.map {
            $0.subscriptionPeriod.value == 1
                ? unitText($0.subscriptionPeriod.unit)
                : periodText($0.subscriptionPeriod)
        }
        let price = unit.map { "\(product.displayPrice) / \($0)" } ?? product.displayPrice
        return String(format: t(.wb_then), price)
    }
}

// MARK: - Banner

/// Sits directly above the plan rows on the paywall when Apple has an offer
/// waiting. Tapping it selects the offered product; the paywall's own button
/// then routes that purchase through `purchaseWithWinBack`.
struct P1WinBackBanner: View {
    let product: Product
    let offer: Product.SubscriptionOffer
    /// True when the paywall's selected plan is the one the offer applies to.
    let isSelected: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.p1Lime)
                    Text(t(.wb_badge).uppercased())
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.p1Lime)
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.p1Lime : Color.p1Mute)
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(P1WinBack.headline(offer))
                    .font(.anton(24))
                    .foregroundStyle(Color.p1Foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(P1WinBack.afterwards(product))
                    .font(.archivo(12))
                    .foregroundStyle(Color.p1Mute)

                Text(t(.wb_body))
                    .font(.archivo(12.5))
                    .lineSpacing(2)
                    .foregroundStyle(Color.p1Ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color.p1Lime.opacity(0.13), Color.p1Panel],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.p1Lime.opacity(isSelected ? 0.85 : 0.4),
                                  lineWidth: isSelected ? 1.6 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.22), value: isSelected)
    }
}

// MARK: - Sheet

/// The offer as a sheet, shown once per offer to a returning lapsed user.
///
/// WHY A SHEET AND NOT ONLY THE PAYWALL BANNER.
///
/// The banner is correct for someone who has already decided to look at the
/// plans. It reaches nobody else. A lapsed user opens the app, sees locked
/// cards, and leaves without ever touching the paywall, which is exactly the
/// behaviour that produced 562 dead subscriptions against 37 live ones. The
/// sheet is the only surface that reaches them where they actually are.
///
/// It fires ONCE per offer id (`pick1.winbackSheetShownFor`) and never again,
/// so a dismissal is respected. A new offer from App Store Connect carries a
/// new id and earns one new showing.
///
/// The record shown is the app's real settled history, wins and losses in the
/// same number. An offer screen is the most tempting place in the product to
/// show only the wins, and it is the one place where doing so would be both
/// an App Review 2.3.1 problem and a contradiction of the whole pitch.
struct Pick1WinBackSheet: View {
    @ObservedObject var vm: PicksViewModel
    /// The offer terms, already resolved. Stored as text rather than as a
    /// `Product.SubscriptionOffer` because that type has no public
    /// initialiser, which would otherwise make this screen impossible to see
    /// until a real offer exists in App Store Connect.
    let headline: String
    let afterwards: String
    /// nil in the review host, where there is nothing to buy.
    let buy: (() async -> Void)?
    var analyticsId: String = "preview"
    var onClose: () -> Void = {}
    var onClaimed: () -> Void = {}

    /// The real one: wording comes off the offer, so the screen can only ever
    /// state terms the App Store will honour.
    @MainActor
    init(vm: PicksViewModel, product: Product, offer: Product.SubscriptionOffer,
         subs: SubscriptionManager,
         onClose: @escaping () -> Void = {}, onClaimed: @escaping () -> Void = {}) {
        self.vm = vm
        self.headline = P1WinBack.headline(offer)
        self.afterwards = P1WinBack.afterwards(product)
        self.buy = { await subs.purchaseWithWinBack(product, offer: offer) }
        self.analyticsId = "\(product.id)|\(offer.id ?? "unnamed")"
        self.onClose = onClose
        self.onClaimed = onClaimed
    }

    /// The review host's: fixed wording, no purchase.
    init(vm: PicksViewModel, headline: String, afterwards: String,
         onClose: @escaping () -> Void = {}) {
        self.vm = vm
        self.headline = headline
        self.afterwards = afterwards
        self.buy = nil
        self.onClose = onClose
    }

    @EnvironmentObject private var subs: SubscriptionManager
    @State private var isBusy = false
    @State private var appeared = false

    private var settled: [Pick] { vm.historyPicks.filter { !$0.isPending } }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.p1Lime.opacity(0.16), Color.p1Ink],
                           startPoint: .top, endPoint: .center)
                .background(Color.p1Ink)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.p1Lime)
                        Text(t(.wb_badge).uppercased())
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(Color.p1Lime)
                    }
                    .padding(.bottom, 16)

                    Text(headline)
                        .font(.anton(40))
                        .foregroundStyle(Color.p1Foreground)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(afterwards)
                        .font(.archivo(13))
                        .foregroundStyle(Color.p1Mute)
                        .padding(.top, 8)

                    Text(t(.wb_sheet_body))
                        .font(.archivo(14.5))
                        .lineSpacing(3)
                        .foregroundStyle(Color.p1Ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)

                    recordPanel
                        .padding(.top, 20)

                    P1PayButtonV2(title: t(.wb_cta), isBusy: isBusy) {
                        guard let buy else { return }
                        isBusy = true
                        Task {
                            await buy()
                            isBusy = false
                            if subs.isPro { onClaimed() }
                        }
                    }
                    .padding(.top, 22)

                    Button(action: onClose) {
                        Text(t(.wb_not_now).uppercased())
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.p1Mute)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { appeared = true }
            Analytics.track("winback_sheet_shown", ["offer": analyticsId])
        }
    }

    /// Wins over settled, and the hit rate, off the same history every other
    /// surface reads. No cherry picking, and no figure that is not already on
    /// screen elsewhere in the app.
    private var recordPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t(.wb_record_label).uppercased())
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(Color.p1Mute)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(vm.totalWins)")
                    .font(.anton(38))
                    .foregroundStyle(Color.p1Foreground)
                Text("/ \(settled.count)")
                    .font(.anton(24))
                    .foregroundStyle(Color.p1Mute)
                Spacer(minLength: 4)
                Text("\(Int(vm.winRate.rounded()))%")
                    .font(.anton(26))
                    .foregroundStyle(Color.p1Lime)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.p1Line, lineWidth: 1))
    }
}
