//  Pick1WinBackV2.swift
//  "Home v2 — Switch Style" — the win-back sheet (`.wback` in the mockup)
//
//  Shown to a lapsed subscriber: the record they missed, three of the actual
//  winning calls, and a come-back offer.
//
//  The record and the three rows are real — they read the same settled history
//  the rest of the app does, which is the whole point of the screen. The OFFER
//  is not yet real: see `winBackOffer`.

import SwiftUI
import StoreKit

struct Pick1WinBackV2: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    /// When the subscription lapsed. Everything shown is scoped to after this.
    var lapsedOn: Date
    var onClose: () -> Void = {}
    var onClaim: () -> Void = {}

    @State private var isBusy = false

    private var since: [Pick] {
        vm.historyPicks.filter { p in
            guard !p.isPending, let d = p.gameDateValue else { return false }
            return d >= lapsedOn
        }
    }

    private var wins: [Pick] { since.filter(\.isWin) }

    /// The three most confident winning calls they missed, one per side —
    /// the same team wins on several nights, and "Minnesota Lynx · called at
    /// 91%" listed twice in a row reads as a rendering fault, not a record.
    private var highlights: [Pick] {
        var seen = Set<String>()
        return wins.sorted { $0.probability > $1.probability }
            .filter { seen.insert($0.pick.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }

    private var monthly: Product? {
        subs.products.first { $0.id == "com.pick1.app.pro.monthly" }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.p1Violet.opacity(0.2), Color.p1Ink],
                           startPoint: .top, endPoint: .center)
                .background(Color.p1Ink)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("WELCOME BACK · REBUILT FROM ZERO")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Color(hex: "#C4A8FF"))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(Color.p1Violet.opacity(0.18)))
                        .overlay(Capsule().strokeBorder(Color.p1Violet.opacity(0.5), lineWidth: 1))

                    (
                        Text("You left.\nThe AI ".uppercased()).foregroundStyle(Color.p1Foreground)
                        + Text("kept winning.".uppercased()).foregroundStyle(Color.p1Lime)
                    )
                    .font(.anton(36))
                    .lineSpacing(-4)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                    Text("EVERYTHING BELOW HAPPENED SINCE YOU CANCELLED")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(0.96)
                        .foregroundStyle(Color.p1Ink2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        Text("THE RECORD WHILE YOU WERE GONE")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Color.p1Mute)

                        (
                            Text("\(wins.count)").font(.anton(44)).foregroundStyle(Color.p1Lime)
                            + Text(" / \(since.count) won").font(.anton(20)).foregroundStyle(Color.p1Ink2)
                        )
                        .padding(.top, 8)

                        VStack(spacing: 7) {
                            ForEach(highlights) { p in
                                HStack(spacing: 10) {
                                    Text("\(emoji(p.sport)) \(p.pick) · called at \(Int(p.probability.rounded()))%")
                                        .font(.archivoNarrow(12, weight: .bold))
                                        .foregroundStyle(Color.p1Foreground)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Spacer(minLength: 8)
                                    Text(String(format: "✓ %.1f×", p.decimalOdds))
                                        .font(.mono(11, weight: .bold))
                                        .foregroundStyle(Color.p1Win)
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Ink))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.p1Line, lineWidth: 1))
                            }
                        }
                        .padding(.top, 12)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.p1Panel))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.p1Line, lineWidth: 1))
                    .padding(.top, 18)

                    winBackOffer
                        .padding(.top, 16)

                    P1PayButtonV2(title: "Claim 50% off", isBusy: isBusy) {
                        guard let monthly else { return }
                        isBusy = true
                        Task {
                            await subs.purchase(monthly)
                            isBusy = false
                            if subs.isPro { onClaim() }
                        }
                    }
                    .padding(.top, 18)

                    Button(action: onClose) {
                        Text("MAYBE LATER")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.32)
                            .foregroundStyle(Color.p1Mute)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)

                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 22)
                .padding(.top, 80)
            }
        }
        .preferredColorScheme(.dark)
        .task { if subs.products.isEmpty { await subs.reloadProducts() } }
    }

    /// ⚠️ The mockup's "$39.99 → $19.99/mo, 50% off for 3 months, expires in
    /// 47:59:12".
    ///
    /// No such offer exists. Delivering it needs a **Win-Back Offer** or an
    /// **Offer Code** configured in App Store Connect and passed to StoreKit
    /// at purchase; the button below currently buys the plan at full price.
    /// The struck-through price and the countdown are therefore rendered from
    /// the real product price with the discount applied locally, so the moment
    /// a real offer is attached this becomes truthful rather than needing a
    /// rewrite. Until then this sheet must not be shown to a real user.
    @ViewBuilder
    private var winBackOffer: some View {
        let full = monthly?.displayPrice ?? "$39.99"
        let half = monthly.map { m -> String in
            (m.price / 2).formatted(m.priceFormatStyle)
        } ?? "$19.99"

        VStack(spacing: 0) {
            (
                Text(full).font(.anton(20)).strikethrough().foregroundStyle(Color.p1Mute)
                + Text("  ").font(.anton(20))
                + Text(half).font(.anton(34)).foregroundStyle(Color.p1Foreground)
                + Text("/mo").font(.anton(16)).foregroundStyle(Color.p1Ink2)
            )
            .padding(.top, 6)

            Text("50% OFF FOR 3 MONTHS · EVERY SPORT · EVERY MARKET")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(0.88)
                .foregroundStyle(Color.p1Ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(
                LinearGradient(colors: [Color.p1Lime.opacity(0.12), Color.p1Panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.p1Lime, lineWidth: 2))
        .overlay(alignment: .top) {
            Text("YOUR COME-BACK OFFER")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.p1Ink)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Color.p1Lime))
                .offset(y: -12)
        }
    }

    private func emoji(_ sport: String) -> String {
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
