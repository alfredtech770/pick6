//  Pick1TrialSaveSheet.swift
//  The in-app save moment for a trial that is about to lapse.
//
//  WHY THIS IS IN-APP AND NOT A PUSH.
//
//  Production numbers on 2026-08-17, from `subscriptions`:
//    • 457 trials have expired without ever paying.
//    • 395 of them ended EXPIRED / VOLUNTARY — the user switched auto-renew
//      off during the 3 free days. It is a decision, not an accident.
//    • Only 40.9% of that cohort has a device token, so push can reach fewer
//      than half of them, and the Resend email fallback is still dormant
//      (7 rows in `email_log`, no RESEND_API_KEY set).
//
//  An in-app sheet is the only channel that reaches 100% of the people who
//  still open the app, which is exactly the population worth saving.
//
//  The argument it makes is Pick1's own: show the record the model actually
//  posted during *their* trial window. No performance promises, no invented
//  numbers — if the model had a bad trial week this sheet says so, which is
//  the same rule the lifecycle-push copy follows and the reason the app's
//  Meta-ads position holds up.

import SwiftUI

struct Pick1TrialSaveSheet: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(\.openURL) private var openURL
    var onClose: () -> Void = {}

    /// Settled picks published inside the user's trial window.
    private var trialPicks: [Pick] {
        guard let expiry = subs.renewal.expiration else { return [] }
        let start = expiry.addingTimeInterval(-3 * 86_400)
        return vm.historyPicks.filter { p in
            guard !p.isPending, let d = p.gameDateValue else { return false }
            return d >= start && d <= expiry
        }
    }

    private var wins: Int { trialPicks.filter(\.isWin).count }
    private var losses: Int { trialPicks.filter(\.isLoss).count }

    /// The strongest calls that landed while they were on trial.
    private var proof: [Pick] {
        var seen = Set<String>()
        return trialPicks.filter(\.isWin)
            .sorted { $0.probability > $1.probability }
            .filter { seen.insert($0.pick.lowercased()).inserted }
            .prefix(3).map { $0 }
    }

    private var hoursLeft: Int {
        Int((subs.renewal.hoursToExpiry ?? 0).rounded(.up))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.p1Lime.opacity(0.12), Color.p1Ink],
                           startPoint: .top, endPoint: .center)
                .background(Color.p1Ink)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(hoursLeft > 0 ? "ACCESS ENDS IN \(hoursLeft)H" : "ACCESS ENDS TODAY")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.p1Hot)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(Color.p1Hot.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Color.p1Hot.opacity(0.5), lineWidth: 1))

                    (
                        Text("Renewal is\n".uppercased()).foregroundStyle(Color.p1Foreground)
                        + Text("switched off.".uppercased()).foregroundStyle(Color.p1Lime)
                    )
                    .font(.anton(36))
                    .lineSpacing(-4)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                    Text("YOU KEEP EVERY PICK UNTIL THEN. NOTHING HAS BEEN CHARGED.")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(0.96)
                        .foregroundStyle(Color.p1Ink2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    // Only shown when the trial window actually produced
                    // settled picks. An empty "here's the record" box on a
                    // quiet slate would argue against itself.
                    if !trialPicks.isEmpty {
                        recordCard.padding(.top, 18)
                    }

                    Button {
                        // Auto-renew lives in the App Store, not in the app —
                        // Apple gives no API to flip it, so the honest CTA is
                        // to take them straight to the right settings screen.
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    } label: {
                        Text("KEEP MY ACCESS")
                            .font(.anton(18))
                            .tracking(0.72)
                            .foregroundStyle(Color.p1Ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(colors: [Color.p1Lime, Color(hex: "#A5D81F")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.p1Lime.opacity(0.3), radius: 17, y: 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)

                    Text("OPENS YOUR APPLE SUBSCRIPTION SETTINGS · TURN RENEWAL BACK ON")
                        .font(.archivoNarrow(10, weight: .semibold))
                        .tracking(0.6)
                        .lineSpacing(5)
                        .foregroundStyle(Color.p1Mute)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Button(action: onClose) {
                        Text("NO THANKS")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.32)
                            .foregroundStyle(Color.p1Mute)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)

                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var recordCard: some View {
        VStack(spacing: 0) {
            Text("WHAT THE MODEL CALLED DURING YOUR TRIAL")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Color.p1Mute)
                .multilineTextAlignment(.center)

            (
                Text("\(wins)").font(.anton(44)).foregroundStyle(Color.p1Lime)
                + Text("W · \(losses)L").font(.anton(20)).foregroundStyle(Color.p1Ink2)
            )
            .padding(.top, 8)

            VStack(spacing: 7) {
                ForEach(proof) { p in
                    HStack(spacing: 10) {
                        Text("\(p.pick) · called at \(Int(p.probability.rounded()))%")
                            .font(.archivoNarrow(12, weight: .bold))
                            .foregroundStyle(Color.p1Foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        Text("✓")
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
    }
}

// MARK: - Presentation gate

/// Decides whether the save sheet should appear. Kept apart from the view so
/// the rule is testable and stated once.
///
/// Fires when the subscription is a trial with auto-renew already off and
/// under 48h left, and at most once per trial period (keyed on the expiry
/// date, so a user who turns renewal back on and later off again is asked
/// again on the *next* period, never twice for the same one).
struct TrialSaveGate {
    @AppStorage("pick1.trialSaveShownForExpiry") private var shownForExpiry: Double = 0

    func shouldPresent(_ renewal: SubscriptionManager.RenewalState) -> Bool {
        guard renewal.isLapsingTrial,
              let expiry = renewal.expiration,
              let hours = renewal.hoursToExpiry,
              hours > 0, hours <= 48
        else { return false }
        return shownForExpiry != expiry.timeIntervalSince1970
    }

    mutating func markPresented(_ renewal: SubscriptionManager.RenewalState) {
        shownForExpiry = renewal.expiration?.timeIntervalSince1970 ?? 0
    }
}
