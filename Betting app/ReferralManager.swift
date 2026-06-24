// ReferralManager.swift
// Two-sided referral: each user has a code; redeeming a friend's code
// grants BOTH 1 free month of Pro (via the pro_grants comp system).
// Backed by the my_referral_code() + redeem_referral() Postgres RPCs.

import Foundation
import Combine
import Supabase

@MainActor
final class ReferralManager: ObservableObject {
    static let shared = ReferralManager()

    @Published private(set) var code: String?

    private init() {}

    /// The Pick1 App Store link used in the share message.
    static let appStoreURL = "https://apps.apple.com/app/id6761689331"

    /// Fetch (minting on first call) the signed-in user's referral code.
    func loadCode() async {
        do {
            let c: String? = try await SupabaseManager.client
                .rpc("my_referral_code")
                .execute()
                .value
            code = c
        } catch {
            // leave nil — the invite screen shows a retry state
        }
    }

    enum RedeemOutcome: Equatable {
        case success
        case invalid
        case alreadyUsed
        case ownCode
        case error
    }

    /// Redeem a friend's code. On success both sides get +1 month Pro.
    func redeem(_ raw: String) async -> RedeemOutcome {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return .invalid }
        struct Resp: Decodable { let ok: Bool; let error: String? }
        do {
            let resp: Resp = try await SupabaseManager.client
                .rpc("redeem_referral", params: ["p_code": trimmed])
                .execute()
                .value
            if resp.ok { return .success }
            switch resp.error {
            case "invalid_code":     return .invalid
            case "already_redeemed": return .alreadyUsed
            case "own_code":         return .ownCode
            default:                 return .error
            }
        } catch {
            return .error
        }
    }
}
