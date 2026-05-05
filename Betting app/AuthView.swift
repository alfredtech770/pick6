// AuthView.swift
// Email OTP authentication flow shown after onboarding.

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Bindable var authManager: AuthManager

    @State private var email: String
    @State private var otpSent: Bool
    @State private var digits: [String] = Array(repeating: "", count: 8)
    @State private var timer = 59
    @State private var direction: Int = 1
    @FocusState private var focusedIndex: Int?

    // Held across the Apple request → completion callback pair
    @State private var appleNonce = ""

    init(authManager: AuthManager) {
        self.authManager = authManager
        // Debug-only: `-PreviewStep otp` jumps straight to the OTP screen
        // with a stub email so it can be screenshotted in isolation.
        let preview = UserDefaults.standard.string(forKey: "PreviewStep") ?? ""
        if preview == "otp" {
            _email = State(initialValue: "you@pick6.app")
            _otpSent = State(initialValue: true)
        } else {
            _email = State(initialValue: "")
            _otpSent = State(initialValue: false)
        }
    }

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
            Color.p1Ink.ignoresSafeArea()

            // Top bar (back when on OTP step)
            VStack(spacing: 0) {
                OBTopBar(
                    canGoBack: otpSent,
                    onBack: otpSent ? {
                        direction = -1
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            otpSent = false
                            digits = Array(repeating: "", count: 6)
                            authManager.error = nil
                        }
                    } : nil
                )
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content
                ZStack {
                    if otpSent {
                        otpView.transition(screenTransition)
                    } else {
                        emailView.transition(screenTransition)
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: otpSent)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            OBStickyBar {
                if otpSent {
                    OBPrimaryButton(
                        label: authManager.isLoading
                            ? "Verifying..."
                            : (isOTPComplete ? "Verify" : "Enter verification code"),
                        disabled: !isOTPComplete || authManager.isLoading,
                        action: verifyCode
                    )
                } else {
                    OBPrimaryButton(
                        label: authManager.isLoading
                            ? "Sending..."
                            : (isValidEmail ? "Send Verification Code" : "Enter your email"),
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
                }
            }
        }
    }

    // MARK: - Email Entry

    private var emailView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OBKicker(text: "ACCOUNT · STEP 1 OF 3")
                    .padding(.bottom, 14)

                OBTitle("CREATE", "YOUR ACCOUNT.", size: 56)

                Text("Get your first AI pick in 30 seconds.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.p1Ink2)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                // Apple Sign In (top per design "show all equally")
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
                        if let authError = error as? ASAuthorizationError,
                           authError.code == .canceled { return }
                        authManager.error = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(authManager.isLoading)

                // Divider
                HStack(spacing: 10) {
                    Rectangle().fill(Color.p1Line).frame(height: 1)
                    Text("OR WITH EMAIL")
                        .font(.custom("BarlowCondensed-Bold", size: 10))
                        .kerning(2.2)
                        .foregroundColor(.p1Mute)
                    Rectangle().fill(Color.p1Line).frame(height: 1)
                }
                .padding(.vertical, 16)

                Text("EMAIL")
                    .font(.custom("BarlowCondensed-Bold", size: 10))
                    .kerning(2.4)
                    .foregroundColor(.p1Mute)
                    .padding(.bottom, 8)

                ZStack(alignment: .leading) {
                    if email.isEmpty {
                        Text(verbatim: "you@domain.com")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.43, green: 0.43, blue: 0.46))
                            .tint(Color(red: 0.43, green: 0.43, blue: 0.46))
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.p1Foreground)
                        .tint(.p1Lime)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                }
                .background(Color.p1Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isValidEmail ? Color.p1Lime : Color.p1Line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let error = authManager.error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.top, 10)
                }

                Text("By continuing you agree to our Terms & Privacy Policy. Must be 21+ to use Pick1.")
                    .font(.system(size: 11))
                    .foregroundColor(.p1Mute)
                    .lineSpacing(3)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 160)
        }
    }

    // MARK: - OTP Verification

    private var otpView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OBKicker(text: "STEP 2 · VERIFY")
                    .padding(.bottom, 14)

                OBTitle("CHECK", "YOUR ", emphasis: "INBOX.", size: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("We sent a 6-digit code to")
                        .foregroundColor(.p1Ink2)
                    Text(email)
                        .foregroundColor(.p1Foreground)
                        .bold()
                }
                .font(.system(size: 13.5))
                .padding(.top, 12)
                .padding(.bottom, 24)

                // OTP boxes
                HStack(spacing: 8) {
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
                .frame(maxWidth: .infinity)

                if let error = authManager.error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Resend
                Group {
                    if timer > 0 {
                        HStack(spacing: 4) {
                            Text("Resend code in").foregroundColor(.p1Mute)
                            Text(String(format: "0:%02d", timer))
                                .foregroundColor(.p1Ink2)
                                .bold()
                        }
                        .font(.system(size: 12, design: .monospaced))
                    } else {
                        Button("Resend code") {
                            digits = Array(repeating: "", count: 6)
                            timer = 59
                            focusedIndex = 0
                            authManager.error = nil
                            Task { await authManager.sendOTP(email: email) }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.p1Lime)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 160)
        }
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
