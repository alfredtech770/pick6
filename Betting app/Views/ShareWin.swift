// ShareWin.swift
// "Share your win" — the viral loop on every graded winner.
//
// From a WON pick the user opens this sheet, types the amount they had
// (or imagine having) on it, and gets a branded card: matchup, the AI's
// call, and their $X → $Y. Sharing it (share sheet completed) rewards
// FREE users with 24 hours of Premium via the claim_share_reward RPC
// (server-capped to one claim per 7 days; grant rides pro_grants).
//
// Apple-safety: the return is explicitly hypothetical — the card and the
// sheet both carry the "we don't take bets" disclaimer, same framing as
// the review-proven $100 → $X displays everywhere else in the app.

import SwiftUI
import UIKit

struct ShareWinSheet: View {
    let pick: Pick
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = "100"
    @State private var showShare = false
    @State private var rewardGranted = false
    @State private var shareImage: UIImage?

    private let lime = Color(hex: "#D4FF3A")

    private var amount: Double {
        max(1, min(100_000, Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 100))
    }
    private var returned: Int { Int((amount * pick.decimalOdds).rounded()) }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color(hex: "#2D3038"))
                .frame(width: 42, height: 5).padding(.top, 10)

            Text(t(.sw_share_win))
                .font(.anton(26)).foregroundColor(.white)

            // Live-updating preview of the exact card that gets shared.
            ShareWinCard(pick: pick, amount: amount, returned: returned)
                .frame(maxWidth: 340)

            // Amount input
            HStack(spacing: 10) {
                Text(t(.sw_your_amount))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#8A8D94"))
                Spacer()
                HStack(spacing: 2) {
                    Text("$").font(.mono(16, weight: .bold)).foregroundColor(lime)
                    TextField("100", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.mono(18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 90)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#16181C")))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(lime.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, 24)

            // Reward hint (free users only) / confirmation
            if rewardGranted {
                Text(t(.sw_reward_done))
                    .font(.archivoNarrow(13, weight: .bold)).tracking(1.2)
                    .foregroundColor(lime)
            } else if !subs.isPro {
                Text(t(.sw_reward_hint))
                    .font(.archivo(12, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }

            Button {
                Haptics.tap()
                shareImage = renderCard()
                showShare = true
            } label: {
                Text(t(.sw_share_cta))
                    .font(.anton(17)).kerning(0.4)
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(lime))
            }
            .padding(.horizontal, 24)

            Text(t(.sw_disclaimer))
                .font(.archivo(10, weight: .medium))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer(minLength: 8)
        }
        // Fill the whole sheet and own its background — without
        // presentationBackground the system sheet gray peeked through
        // around the content.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0A0B0D"))
        .presentationBackground(Color(hex: "#0A0B0D"))
        .presentationDragIndicator(.visible)
        .onAppear { Analytics.shareWinOpened(league: pick.league) }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareActivitySheet(items: [img]) { completed in
                    guard completed else {
                        Analytics.shareWinCompleted(granted: false)
                        return
                    }
                    Haptics.success()
                    // Reward only for free users; server enforces the
                    // 7-day cooldown + signs the grant.
                    if !subs.isPro {
                        Task {
                            let granted = await subs.claimShareReward()
                            Analytics.shareWinCompleted(granted: granted)
                            if granted {
                                withAnimation { rewardGranted = true }
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// Rasterize the card at 3x for a crisp share image.
    @MainActor
    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content:
            ShareWinCard(pick: pick, amount: amount, returned: returned)
                .frame(width: 340)
                .background(Color(hex: "#0A0B0D"))
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// The branded card image itself — dark canvas, P1 wordmark, matchup,
/// the AI call with a WON chip, and the user's $X → $Y in Anton.
struct ShareWinCard: View {
    let pick: Pick
    let amount: Double
    let returned: Int
    private let lime = Color(hex: "#D4FF3A")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Pick1Wordmark(size: 22)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                    Text(t(.rd_won)).font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                }
                .foregroundColor(Color(hex: "#0A0B0D"))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(lime))
            }

            Text("\(teamShortName(pick.awayTeam, sport: pick.sport).uppercased())  VS  \(teamShortName(pick.homeTeam, sport: pick.sport).uppercased())")
                .font(.anton(20)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)

            HStack(spacing: 6) {
                Text(t(.rd_ai_picks))
                    .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#8A8D94"))
                Text(pick.shortDisplayPick.uppercased())
                    .font(.archivoNarrow(12, weight: .bold)).tracking(1.2)
                    .foregroundColor(lime)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$\(Int(amount.rounded()))")
                    .font(.anton(34)).foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(lime)
                Text("$\(returned)")
                    .font(.anton(44)).foregroundColor(lime)
            }

            Text(t(.sw_disclaimer))
                .font(.archivo(8, weight: .medium))
                .foregroundColor(Color(hex: "#6E6F75"))
                .lineLimit(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#101114"))
                .overlay(
                    LinearGradient(colors: [lime.opacity(0.16), .clear],
                                   startPoint: .topLeading, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                )
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(lime.opacity(0.45), lineWidth: 1.2))
        )
    }
}

/// UIActivityViewController wrapper that reports whether the user
/// actually completed a share (dismissing without sharing = false —
/// no reward for cancelled sheets).
struct ShareActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDone: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            onDone(completed)
        }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
