//  Pick1RecoveryBanners.swift
//  The two in-app surfaces that catch a subscription on its way out.
//
//  WHY THESE EXIST.
//
//  Production state on 2026-08-24, from `subscriptions`:
//    • 37 people are paying.
//    • 41 are in billing retry — MORE than are paying. Every one of them
//      agreed to pay and had a card decline. Apple's own retry recovered 2.
//    • 405 trials ended EXPIRED / VOLUNTARY: the user switched auto-renew
//      off during the 3 free days. That is a decision, not an accident.
//
//  Push reaches under half of those people (device tokens) and email reaches
//  none of them (Pick1 has never sent one). The app itself is the only
//  channel that reaches everyone who still opens it, and it was saying
//  nothing at all — a user in billing retry saw the same locked screen as
//  someone who had never subscribed.
//
//  Neither banner promises a return. The trial banner's whole argument is
//  Pick1's own: here is the record the model actually posted during YOUR
//  trial window, wins and losses. If the model had a bad week it says so.

import SwiftUI
import StoreKit

// MARK: - Billing retry

/// Shown when Apple could not charge the card and Pro is paused.
///
/// The CTA opens Apple's own manage-subscriptions sheet, which is the only
/// place a payment method can actually be fixed. We never ask for card
/// details ourselves.
struct P1BillingRetryBanner: View {
    var onDismiss: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @State private var opening = false

    private let alert = Color(hex: "#FF8A3D")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(alert)
                Text(t(.rec_billing_title))
                    .font(.anton(15))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(V4.mute)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t(.rec_billing_dismiss))
            }

            Text(t(.rec_billing_body))
                .font(.archivo(12.5))
                .lineSpacing(2)
                .foregroundStyle(V4.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                guard !opening else { return }
                opening = true
                Haptics.tap()
                Task {
                    // showManageSubscriptions needs a window scene; the URL
                    // fallback is what works when the scene lookup fails
                    // (iPad multi-scene, or the sheet being mid-transition).
                    if let scene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene }).first {
                        try? await AppStore.showManageSubscriptions(in: scene)
                    } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                    opening = false
                }
            } label: {
                Text(t(.rec_billing_cta).uppercased())
                    .font(.anton(13))
                    .tracking(0.6)
                    .foregroundStyle(Color(hex: "#171717"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(alert))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [alert.opacity(0.12), V4.panelBot],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(alert.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Lapsing trial

/// Shown when the user is mid-trial and has already switched renewal off.
///
/// Deliberately a banner and not a second sheet: `Pick1TrialSaveSheet` is the
/// full argument and fires once per trial period, and a user who dismissed it
/// should not be handed the same sheet again. The banner stays as a quiet way
/// back to it for the rest of the trial.
struct P1LapsingTrialBanner: View {
    let hoursLeft: Int
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(V4.gold)
                    Text(t(.rec_trial_banner_title, count: max(hoursLeft, 1)))
                        .font(.anton(15))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(V4.mute)
                }
                Text(t(.rec_trial_banner_body))
                    .font(.archivo(12.5))
                    .lineSpacing(2)
                    .foregroundStyle(V4.ink2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(t(.rec_trial_banner_cta).uppercased())
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(V4.gold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [V4.gold.opacity(0.10), V4.panelBot],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(V4.gold.opacity(0.40), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
