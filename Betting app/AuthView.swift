// AuthView.swift
// Email OTP authentication flow shown after onboarding.

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Bindable var authManager: AuthManager

    @State private var email = ""
    @State private var otpSent = false
    @State private var digits: [String] = Array(repeating: "", count: 8)
    @State private var timer = 59
    @State private var direction: Int = 1
    @FocusState private var focusedIndex: Int?

    // Held across the Apple request → completion callback pair
    @State private var appleNonce = ""

    private var isValidEmail: Bool {
        let pattern = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        return email.wholeMatch(of: pattern) != nil
    }

    private var isOTPComplete: Bool {
        digits.filter { !$0.isEmpty }.count == 6
    }

    private var otpCode: String {
        digits.joined()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.p6Ink.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    if otpSent {
                        Button {
                            direction = -1
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                otpSent = false
                                digits = Array(repeating: "", count: 6)
                                authManager.error = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 8)

                // Content
                ZStack {
                    if otpSent {
                        otpView
                            .transition(screenTransition)
                    } else {
                        emailView
                            .transition(screenTransition)
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: otpSent)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Email Entry

    private var emailView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CREATE YOUR")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1)
                .foregroundColor(.white)
            Text("ACCOUNT")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1)
                .foregroundColor(Color.white.opacity(0.16))
                .padding(.bottom, 24)

            Text("Email address")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.bottom, 10)

            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.custom("BarlowCondensed-Bold", size: 18))
                .foregroundColor(.white)
                .tint(.p6Red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 14)

            // Error
            if let error = authManager.error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.bottom, 10)
            }

            P6Button(
                authManager.isLoading
                    ? "Sending..."
                    : (isValidEmail ? "Send Verification Code \u{2192}" : "Enter your email"),
                gradient: isValidEmail && !authManager.isLoading ? .redDeep : nil,
                disabled: !isValidEmail || authManager.isLoading
            ) {
                Task {
                    await authManager.sendOTP(email: email)
                    if authManager.error == nil {
                        direction = 1
                        withAnimation { otpSent = true }
                    }
                }
            }

            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.3))
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
            }
            .padding(.vertical, 20)

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256Hex(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard
                        let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                        let tokenData = credential.identityToken,
                        let idToken = String(data: tokenData, encoding: .utf8)
                    else {
                        authManager.error = "Apple Sign In failed. Please try again."
                        return
                    }
                    Task {
                        await authManager.signInWithApple(idToken: idToken, nonce: appleNonce)
                    }
                case .failure(let error):
                    // Ignore user-cancelled
                    if let authError = error as? ASAuthorizationError,
                       authError.code == .canceled { return }
                    authManager.error = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(authManager.isLoading)

            Spacer()

            Text("By continuing you agree to our Terms of Service and Privacy Policy")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.22))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    // MARK: - OTP Verification

    private var otpView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lock icon
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.p6Red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.p6Red.opacity(0.3), lineWidth: 1.5)
                    )
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.p6Red)
            }
            .frame(width: 54, height: 54)
            .padding(.bottom, 22)

            Text("VERIFY YOUR\nEMAIL")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1)
                .foregroundColor(.white)
                .padding(.bottom, 10)

            Text("We sent a 6-digit code to\n**\(email)**")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.5))
                .lineSpacing(3)
                .padding(.bottom, 28)

            // OTP boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    OTPBox(
                        digit: $digits[i],
                        isFocused: focusedIndex == i,
                        onFilled: {
                            if i < 5 {
                                focusedIndex = i + 1
                            } else {
                                verifyCode()
                            }
                        },
                        onBackspace: {
                            if i > 0 {
                                digits[i - 1] = ""
                                focusedIndex = i - 1
                            }
                        }
                    )
                    .focused($focusedIndex, equals: i)
                }
            }
            .padding(.bottom, 14)

            // Error
            if let error = authManager.error {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.bottom, 10)
            }

            P6Button(
                authManager.isLoading
                    ? "Verifying..."
                    : (isOTPComplete ? "Verify & Continue \u{2192}" : "Enter verification code"),
                gradient: isOTPComplete && !authManager.isLoading ? .redDeep : nil,
                disabled: !isOTPComplete || authManager.isLoading,
                action: verifyCode
            )

            // Resend
            VStack(spacing: 4) {
                Text("Didn't receive it?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.4))
                if timer > 0 {
                    Text("Resend code in \(String(format: "0:%02d", timer))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.35))
                } else {
                    Button("Resend code") {
                        digits = Array(repeating: "", count: 6)
                        timer = 59
                        focusedIndex = 0
                        authManager.error = nil
                        Task { await authManager.sendOTP(email: email) }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.p6Red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)

            Spacer()

            Text("By verifying you agree to our Terms of Service and Privacy Policy")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.22))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .onAppear {
            focusedIndex = 0
            startTimer()
        }
    }

    // MARK: - Helpers

    private func verifyCode() {
        guard isOTPComplete else { return }
        Task {
            await authManager.verifyOTP(email: email, token: otpCode)
        }
    }

    private func startTimer() {
        guard timer > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if timer > 0 { timer -= 1; startTimer() }
        }
    }

    private var screenTransition: AnyTransition {
        direction == 1
            ? .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
            : .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
    }
}
