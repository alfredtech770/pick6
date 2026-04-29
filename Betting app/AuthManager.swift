// AuthManager.swift
// Manages Supabase authentication state (email OTP + Apple Sign In).

import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isProfileComplete = false
    var isCheckingSession = true   // true until first checkSession() resolves
    var userEmail: String?
    var firstName: String?
    var lastName: String?
    var whatsapp: String?
    var isLoading = false
    var error: String?

    var displayName: String {
        if let f = firstName, let l = lastName { return "\(f) \(l)".uppercased() }
        return "BETTOR"
    }

    private var authListener: Task<Void, Never>?

    init() {
        listenToAuthChanges()
    }

    deinit {
        authListener?.cancel()
    }

    // MARK: - Session

    func checkSession() async {
        do {
            let session = try await SupabaseManager.client.auth.session
            isAuthenticated = true
            userEmail = session.user.email
            await loadProfile(userId: session.user.id)
        } catch {
            // No valid session in Keychain — show login screen
            isAuthenticated = false
            isProfileComplete = false
        }
        isCheckingSession = false
    }

    // MARK: - Profile

    private struct ProfileRow: Decodable {
        let id: String
        let first_name: String
        let last_name: String
        let whatsapp: String
    }

    private struct ProfileUpsert: Encodable {
        let id: String
        let first_name: String
        let last_name: String
        let whatsapp: String
        let date_of_birth: String
    }

    private func loadProfile(userId: UUID) async {
        do {
            let row: ProfileRow = try await SupabaseManager.client
                .from("profiles")
                .select("id, first_name, last_name, whatsapp")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            firstName = row.first_name
            lastName  = row.last_name
            whatsapp  = row.whatsapp
            isProfileComplete = true
        } catch {
            // Profile row doesn't exist yet — send to profile setup
            isProfileComplete = false
        }
    }

    func saveProfile(firstName: String, lastName: String, whatsapp: String, dateOfBirth: Date) async {
        isLoading = true
        error = nil
        do {
            let session = try await SupabaseManager.client.auth.session
            let dobFormatter = DateFormatter()
            dobFormatter.dateFormat = "yyyy-MM-dd"

            try await SupabaseManager.client
                .from("profiles")
                .upsert(ProfileUpsert(
                    id: session.user.id.uuidString,
                    first_name: firstName,
                    last_name: lastName,
                    whatsapp: whatsapp,
                    date_of_birth: dobFormatter.string(from: dateOfBirth)
                ))
                .execute()

            self.firstName = firstName
            self.lastName  = lastName
            self.whatsapp  = whatsapp
            isProfileComplete = true
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - OTP

    func sendOTP(email: String) async {
        isLoading = true
        error = nil
        do {
            try await SupabaseManager.client.auth.signInWithOTP(email: email)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func verifyOTP(email: String, token: String) async {
        isLoading = true
        error = nil
        do {
            try await SupabaseManager.client.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )
            isLoading = false
        } catch {
            self.error = "Invalid verification code. Please try again."
            isLoading = false
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(idToken: String, nonce: String) async {
        isLoading = true
        error = nil
        do {
            try await SupabaseManager.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
            isAuthenticated = false
            isProfileComplete = false
            userEmail = nil
            // Reset the local onboarding flag so signing out returns the user
            // to the welcome flow on next launch.
            UserDefaults.standard.set(false, forKey: "hasFinishedOnboarding")
            UserDefaults.standard.set("", forKey: "selectedSports")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthChanges() {
        authListener = Task { [weak self] in
            for await (event, session) in SupabaseManager.client.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .signedIn:
                    self.isAuthenticated = true
                    self.userEmail = session?.user.email
                    if let userId = session?.user.id {
                        await self.loadProfile(userId: userId)
                    }
                case .signedOut:
                    self.isAuthenticated = false
                    self.isProfileComplete = false
                    self.userEmail = nil
                    self.firstName = nil
                    self.lastName  = nil
                    self.whatsapp  = nil
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Nonce Helpers (used by AuthView)

func randomNonceString(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    return randomBytes.map { String(format: "%02x", $0) }.joined()
}

func sha256Hex(_ input: String) -> String {
    let hashed = SHA256.hash(data: Data(input.utf8))
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}
