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
        var dc = DateComponents()
        let n = p.value * max(times, 1)
        switch p.unit {
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
            return String(format: t(.wb_each_for), offer.displayPrice,
                          periodText(offer.period),
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
        let unit = product.subscription.map { periodText($0.subscriptionPeriod) } ?? ""
        let price = unit.isEmpty ? product.displayPrice : "\(product.displayPrice) / \(unit)"
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
