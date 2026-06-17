// AuthManager.swift
// Manages Supabase authentication state (email OTP + Apple Sign In).
//
// Concurrency notes:
//   • `@MainActor` annotation keeps every @Observable mutation on main, so
//     SwiftUI doesn't re-render off-thread. The class also owns long-lived
//     UI state (isAuthenticated, userEmail, error string), which all
//     naturally belong on main.
//   • The single `Task` in `listenToAuthChanges` inherits the actor; the
//     async sequence is delivered on main, so we don't need explicit hops.

import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit

extension Notification.Name {
    /// Posted by AuthManager when the user signs out or deletes their
    /// account, so per-user in-memory stores (e.g. FavoritesStore) can
    /// wipe themselves and not leak data to the next user on the device.
    static let pick1UserDidSignOut = Notification.Name("pick1UserDidSignOut")
}

/// Distinguishes "no session" (normal: user is logged out) from "we
/// couldn't reach the server" (transient: don't bounce the user back to
/// welcome — show a retry banner). Used by the splash flow to decide
/// whether to clear UI state vs hold the loader and offer retry.
enum SessionCheckOutcome {
    case authenticated
    case noSession
    case networkUnavailable
}

@MainActor
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

    /// Set to true when the last `checkSession` failed because the
    /// network/Supabase was unreachable (NOT because the user has no
    /// session). The splash flow watches this to show a retry banner
    /// instead of silently logging the user out on a flaky cell.
    var networkUnavailable = false

    var displayName: String {
        if let f = firstName, let l = lastName { return "\(f) \(l)".uppercased() }
        return "PICK1 FAN"
    }

    // `nonisolated(unsafe)` because deinit runs on whatever queue ARC
    // dropped the last reference on, but we need to cancel the listener
    // from there. The Task itself is well-behaved (weak self check
    // exits on first iteration after dealloc), so the cancel is a
    // safety belt, not load-bearing.
    private nonisolated(unsafe) var authListener: Task<Void, Never>?

    init() {
        listenToAuthChanges()
    }

    deinit {
        authListener?.cancel()
    }

    // MARK: - Session

    /// Restore the session from Keychain on launch. Distinguishes:
    ///   • Valid session  → isAuthenticated=true, loadProfile
    ///   • No session     → isAuthenticated=false (welcome flow)
    ///   • Network error  → networkUnavailable=true, KEEP previous auth
    ///                      state (don't bounce returning users on a
    ///                      flaky cell — the splash shows a retry).
    @discardableResult
    func checkSession() async -> SessionCheckOutcome {
        // Minimum splash hold — keeps the loader visible for at least
        // 3.5s so the brand mark + ticker get a beat to land before
        // the home screen swaps in. Real session work runs in
        // parallel; we only block on whichever finishes last.
        let started = Date()
        let minimumSplash: TimeInterval = 3.5

        var outcome: SessionCheckOutcome = .noSession
        networkUnavailable = false

        // Optimistic restore: if a session exists locally (Keychain),
        // treat the user as signed in immediately — even if the network
        // validation below fails transiently. A returning user on a
        // flaky cell must never be bounced to the welcome screen while
        // a session sits on the device; if the token is truly revoked,
        // the authStateChanges listener will sign them out properly.
        if let local = SupabaseManager.client.auth.currentSession {
            isAuthenticated = true
            userEmail = local.user.email
        }

        do {
            let session = try await SupabaseManager.client.auth.session
            isAuthenticated = true
            userEmail = session.user.email
            await loadProfile(userId: session.user.id)
            outcome = .authenticated
        } catch {
            // Tell apart "no session in keychain" (expected) from
            // "couldn't reach Supabase" (transient). The Supabase-Swift
            // SDK throws a generic AuthError for both — we sniff the
            // underlying NSError code or message string.
            if isNetworkError(error) {
                // Don't change isAuthenticated — preserve whatever was
                // there. The retry banner will offer to try again.
                networkUnavailable = true
                outcome = .networkUnavailable
            } else {
                isAuthenticated = false
                isProfileComplete = false
                outcome = .noSession
            }
        }

        let elapsed = Date().timeIntervalSince(started)
        if elapsed < minimumSplash {
            try? await Task.sleep(
                nanoseconds: UInt64((minimumSplash - elapsed) * 1_000_000_000)
            )
        }
        isCheckingSession = false
        return outcome
    }

    /// Heuristic: does this error look like network unreachability vs a
    /// real auth failure? We don't want to mis-categorize "invalid
    /// refresh token" as a network problem (that would loop the retry
    /// banner forever).
    private nonisolated func isNetworkError(_ error: Error) -> Bool {
        let ns = error as NSError
        // URLError codes for offline / DNS / timeout
        if ns.domain == NSURLErrorDomain {
            let offlineCodes: Set<Int> = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorInternationalRoamingOff,
                NSURLErrorDataNotAllowed
            ]
            return offlineCodes.contains(ns.code)
        }
        // Best-effort string sniff for SDK-wrapped errors
        let msg = error.localizedDescription.lowercased()
        return msg.contains("offline")
            || msg.contains("network")
            || msg.contains("timed out")
            || msg.contains("cannot connect")
            || msg.contains("could not connect")
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
        Analytics.identify(userId.uuidString)
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
            // Profile row doesn't exist yet — send to profile setup.
            // (Network errors here are not fatal: the user can still
            // re-enter their profile; loadProfile is retried on every
            // app launch.)
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
            self.error = friendlyError(error)
            isLoading = false
        }
    }

    // MARK: - OTP

    // MARK: App Review demo account
    //
    // Apple requires a functional demo login (Guideline 2.1 / demo
    // account), but Pick1 is passwordless — reviewers can't receive
    // our OTP emails. For exactly ONE allow-listed address we accept a
    // static verification code and sign in via a password grant under
    // the hood. The account is a throwaway with no privileges; RLS
    // gives it the same read-only access as any user.
    private static let reviewerEmail = "review@pick1.live"
    private static let reviewerStaticCode = "070770"
    private static let reviewerPassword = "p1ReviewDemo!2026#OTP"

    private func isReviewerEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == Self.reviewerEmail
    }

    func sendOTP(email: String) async {
        isLoading = true
        error = nil
        // Reviewer account: no email is actually sent — the static
        // code in the App Review notes is entered on the next screen.
        if isReviewerEmail(email) {
            isLoading = false
            return
        }
        do {
            try await SupabaseManager.client.auth.signInWithOTP(email: email)
            isLoading = false
        } catch {
            self.error = friendlyError(error)
            isLoading = false
        }
    }

    func verifyOTP(email: String, token: String) async {
        // Debounce double-fire: SMS/mail autofill can populate all six
        // OTP boxes at once and trigger verify twice in the same tick.
        // The second call burns the just-used token (403 otp_expired)
        // and surfaces a spurious "invalid code" error over a login
        // that actually succeeded.
        guard !isLoading else { return }
        isLoading = true
        error = nil
        // Reviewer account + static code → password grant (see note above).
        if isReviewerEmail(email), token == Self.reviewerStaticCode {
            do {
                try await SupabaseManager.client.auth.signIn(
                    email: Self.reviewerEmail,
                    password: Self.reviewerPassword
                )
                isLoading = false
            } catch {
                self.error = friendlyError(error)
                isLoading = false
            }
            return
        }
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

    // MARK: - Password update

    /// Set or change the user's account password. Pick1 sign-in is
    /// passwordless by default (email OTP / Sign in with Apple), but
    /// Supabase still lets us attach a password to the account so the
    /// user can opt into a second auth path. Throws on validation
    /// errors (too short, too weak, etc.).
    func updatePassword(_ newPassword: String) async {
        isLoading = true
        error = nil
        do {
            try await SupabaseManager.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            isLoading = false
        } catch {
            self.error = friendlyError(error)
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
            // Capture the EXACT server-side reason (e.g. "Unacceptable
            // audience in id_token") so a SIWA failure is never a blind
            // guess again — surfaces in PostHog even when we can't repro.
            Analytics.track("apple_signin_failed", [
                "stage": "supabase_token_exchange",
                "message": String(String(describing: error).prefix(300)),
            ])
            self.error = friendlyError(error)
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        // Clear local state FIRST — the UI must flip to the welcome
        // flow immediately. The remote revocation below is best-effort:
        // on a flaky connection it can hang (not fail), and awaiting it
        // before clearing state made Sign Out appear to do nothing
        // (App Review 2.1(a)).
        clearLocalUserState()
        do {
            try await SupabaseManager.client.auth.signOut()
        } catch {
            // Remote revocation failed — local state is already gone,
            // so the user is signed out on this device regardless.
        }
    }

    /// Reset every piece of per-user state stored locally. Called after
    /// signOut / deleteAccount so a different user signing in next on
    /// the same device starts clean (no leaked favorites, sport
    /// selection, plan selection, or onboarding flag).
    private func clearLocalUserState() {
        isAuthenticated = false
        isProfileComplete = false
        userEmail = nil
        firstName = nil
        lastName  = nil
        whatsapp  = nil

        let d = UserDefaults.standard
        d.set(false, forKey: "hasFinishedOnboarding")
        d.set("",    forKey: "selectedSports")
        d.removeObject(forKey: "selectedPlan")
        d.removeObject(forKey: "pick1.favoriteMatchIds.v1")
        d.removeObject(forKey: "pick1.ageVerified")

        // Tell FavoritesStore (and any other per-user in-memory store) to
        // wipe itself — removing the key above only clears the persisted
        // copy, not the live @Published set held in memory this session.
        NotificationCenter.default.post(name: .pick1UserDidSignOut, object: nil)
    }

    // MARK: - Account Deletion (App Store guideline 5.1.1(v))

    /// Permanently delete the signed-in user. Required by Apple since
    /// 2022 for any app with account creation (guideline 5.1.1(v)).
    /// Calls the `public.delete_current_user()` Postgres function which
    /// is `security definer` — it executes as the function owner but
    /// pins to `auth.uid()` of the caller, so a user can ONLY delete
    /// their own account. The function:
    ///   1. Deletes the `auth.users` row.
    ///   2. Cascade-deletes `profiles` via the FK on profiles.id.
    ///   3. Any other user-owned tables (favorites, etc.) must also
    ///      have ON DELETE CASCADE on their user_id FK.
    /// After success we sign out locally and clear all device state.
    @discardableResult
    func deleteAccount() async -> Bool {
        isLoading = true
        error = nil
        do {
            try await SupabaseManager.client
                .rpc("delete_current_user")
                .execute()
            // Sign out locally and wipe device state. The remote signOut
            // call may 401 because the user row is gone — that's fine,
            // we just need to clear local keychain entries.
            try? await SupabaseManager.client.auth.signOut()
            clearLocalUserState()
            isLoading = false
            return true
        } catch {
            self.error = friendlyError(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Error formatting

    /// Translate raw SDK errors into user-presentable strings. Network
    /// errors get a recognizable "couldn't reach server" message so the
    /// UI can offer a retry; everything else falls back to the SDK's
    /// localizedDescription.
    private nonisolated func friendlyError(_ error: Error) -> String {
        if isNetworkError(error) {
            return "Couldn't reach the Pick1 server. Check your connection and try again."
        }
        return error.localizedDescription
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
                    self.clearLocalUserState()
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
