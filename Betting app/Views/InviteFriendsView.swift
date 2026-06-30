// InviteFriendsView.swift
// Two-sided referral screen: share your code (you both get a free month),
// and redeem a friend's code. Opened from Profile.

import SwiftUI

struct InviteFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationManager.self) private var loc
    @EnvironmentObject private var subs: SubscriptionManager
    @StateObject private var referral = ReferralManager.shared

    @State private var entered = ""
    @State private var redeeming = false
    @State private var banner: (text: String, ok: Bool)?

    private let lime = Color(hex: "#D4FF3A")
    private let ink = Color(hex: "#0A0B0D")

    private var shareText: String {
        let code = referral.code ?? ""
        return String(format: loc.t(.referral_share_msg), code, ReferralManager.appStoreURL)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                grabber
                header

                // Hero
                Image(systemName: "gift.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(lime)
                    .padding(.top, 8)
                Text(loc.t(.referral_subtitle))
                    .font(.archivo(14, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 10)

                codeCard.padding(.top, 22)
                if let code = referral.code, !code.isEmpty {
                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text(loc.t(.referral_share_cta))
                                .font(.archivoNarrow(13, weight: .heavy))
                                .tracking(1.2)
                        }
                        .foregroundColor(ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(lime))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                }

                redeemSection.padding(.top, 30)

                Color.clear.frame(height: 30)
            }
        }
        .background(ink.ignoresSafeArea())
        .task { await referral.loadCode() }
    }

    private var grabber: some View {
        Capsule().fill(Color(hex: "#2D3038"))
            .frame(width: 38, height: 5).padding(.top, 8).padding(.bottom, 10)
    }

    private var header: some View {
        HStack {
            Text(loc.t(.referral_title))
                .font(.anton(24)).foregroundColor(Color(hex: "#F5F3EE"))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(hex: "#16181C")))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var codeCard: some View {
        VStack(spacing: 8) {
            Text(loc.t(.referral_your_code))
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(referral.code ?? "······")
                .font(.custom("BarlowCondensed-Black", size: 40))
                .tracking(6)
                .foregroundColor(lime)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(lime.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(lime.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 22)
    }

    private var redeemSection: some View {
        VStack(spacing: 10) {
            Text(loc.t(.referral_have_code))
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(Color(hex: "#6E6F75"))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                TextField(loc.t(.referral_enter), text: $entered)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.archivo(15, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#101114")))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#22252B"), lineWidth: 1))

                Button {
                    Task { await redeem() }
                } label: {
                    Group {
                        if redeeming { ProgressView().tint(ink) }
                        else { Text(loc.t(.referral_redeem)).font(.archivoNarrow(13, weight: .heavy)).tracking(1) }
                    }
                    .foregroundColor(ink)
                    .frame(width: 96, height: 46)
                    .background(Capsule().fill(entered.isEmpty ? Color(hex: "#3A3D44") : lime))
                }
                .buttonStyle(.plain)
                .disabled(entered.isEmpty || redeeming)
            }

            if let banner {
                Text(banner.text)
                    .font(.archivo(12, weight: .medium))
                    .foregroundColor(banner.ok ? Color(hex: "#4ade80") : Color(hex: "#FF5A36"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 22)
    }

    private func redeem() async {
        redeeming = true; banner = nil
        let outcome = await referral.redeem(entered)
        redeeming = false
        switch outcome {
        case .success(let grantedPro):
            banner = (loc.t(grantedPro ? .referral_redeemed : .code_applied), true)
            entered = ""
            Haptics.success()
            await subs.refreshCompAccess()   // unlock immediately (on comp-enabled builds)
        case .invalid, .ownCode:
            banner = (loc.t(.referral_err_invalid), false)
        case .alreadyUsed:
            banner = (loc.t(.referral_err_used), false)
        case .error:
            banner = (loc.t(.error_generic), false)
        }
    }
}
