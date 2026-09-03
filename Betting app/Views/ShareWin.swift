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

    private let lime = Color(hex: "#C6FF34")

    private var amount: Double {
        max(1, min(100_000, Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 100))
    }
    /// Nothing comes back from a losing call. The card says $0, not a
    /// hypothetical, because a share card that quietly prices a loss as a
    /// win is the exact thing this product exists not to do.
    private var returned: Int { pick.isWin ? Int((amount * pick.decimalOdds).rounded()) : 0 }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color(hex: "#3A3A3A"))
                .frame(width: 42, height: 5).padding(.top, 10)

            Text(pick.isWin ? t(.sw_share_win) : t(.sw_share_result))
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
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#232323")))
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
                    .foregroundColor(Color(hex: "#171717"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(pick.isWin ? lime : Color(hex: "#FF6B57")))
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
        .background(Color(hex: "#171717"))
        .presentationBackground(Color(hex: "#171717"))
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
                .background(Color(hex: "#171717"))
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
    private let lime = Color(hex: "#C6FF34")

    /// The shared image is the SAME ticket the detail page shows, tilted a
    /// few degrees so it reads as a slip someone is holding rather than a
    /// screenshot of a row. Reusing the component instead of drawing a second
    /// card means the thing people pass around cannot drift away from the
    /// thing the app shows, which is the whole point of a public record.
    ///
    /// It is shared for LOSSES too. A record you can only pass on when it
    /// flatters you is not a record.
    private var won: Bool { pick.isWin }
    private var accent: Color { won ? lime : Color(hex: "#FF6B57") }

    /// Both of these mirror the detail page exactly. The ticket takes a
    /// confidence TIER for its sub-line and prints the percentage itself, so
    /// passing the percentage in printed "55%" twice, once large and once
    /// small underneath. And the logged time is stamped in the pipeline's
    /// timezone, not the reader's, or two people sharing the same call would
    /// show different times on the same ticket.
    private var confidenceTierText: String {
        let raw = pick.confidence.lowercased()
        if ["high", "medium", "low"].contains(raw) { return raw.capitalized }
        switch pick.confidenceTier {
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        }
    }

    private var loggedText: String {
        guard let d = pick.createdAt else { return "PRE-GAME" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: d)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Pick1Wordmark(size: 20)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: won ? "checkmark" : "xmark")
                        .font(.system(size: 9, weight: .heavy))
                    Text(won ? t(.rd_won) : t(.rd_lost))
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                }
                .foregroundColor(Color(hex: "#171717"))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(accent))
            }

            P1PickTicket(pick: pick,
                         homeScore: pick.homeScore,
                         awayScore: pick.awayScore,
                         confidence: confidenceTierText,
                         loggedAt: loggedText)
                .rotationEffect(.degrees(-2.5))
                // The tilt swings the corners out; this keeps them inside the
                // rendered image instead of clipping them off.
                .padding(.horizontal, 10)
                .padding(.vertical, 12)

            // The stake the sharer chose, and what it came back as. $0 on a
            // loss, never a hypothetical dressed as a return.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$\(Int(amount.rounded()))")
                    .font(.anton(26)).foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(accent)
                Text("$\(returned)")
                    .font(.anton(34)).foregroundColor(accent)
                Spacer()
            }

            Text(t(.sw_disclaimer))
                .font(.archivo(8, weight: .medium))
                .foregroundColor(Color(hex: "#6E6F75"))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(
                    LinearGradient(colors: [accent.opacity(0.14), .clear],
                                   startPoint: .topLeading, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                )
                .overlay(RoundedRectangle(cornerRadius: 22)
                    .stroke(accent.opacity(0.40), lineWidth: 1.2))
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
