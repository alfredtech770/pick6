// ProfileSetupView.swift
// Collects user profile info after initial authentication.

import SwiftUI

// MARK: - Country code model

private struct CountryCode: Identifiable, Hashable {
    let id = UUID()
    let flag: String
    let name: String
    let dial: String   // e.g. "+33"
}

private let countryCodes: [CountryCode] = [
    CountryCode(flag: "🇫🇷", name: "France",         dial: "+33"),
    CountryCode(flag: "🇬🇧", name: "United Kingdom",  dial: "+44"),
    CountryCode(flag: "🇺🇸", name: "United States",   dial: "+1"),
    CountryCode(flag: "🇩🇪", name: "Germany",         dial: "+49"),
    CountryCode(flag: "🇪🇸", name: "Spain",           dial: "+34"),
    CountryCode(flag: "🇮🇹", name: "Italy",           dial: "+39"),
    CountryCode(flag: "🇵🇹", name: "Portugal",        dial: "+351"),
    CountryCode(flag: "🇧🇪", name: "Belgium",         dial: "+32"),
    CountryCode(flag: "🇳🇱", name: "Netherlands",     dial: "+31"),
    CountryCode(flag: "🇨🇭", name: "Switzerland",     dial: "+41"),
    CountryCode(flag: "🇦🇹", name: "Austria",         dial: "+43"),
    CountryCode(flag: "🇵🇱", name: "Poland",          dial: "+48"),
    CountryCode(flag: "🇸🇪", name: "Sweden",          dial: "+46"),
    CountryCode(flag: "🇳🇴", name: "Norway",          dial: "+47"),
    CountryCode(flag: "🇩🇰", name: "Denmark",         dial: "+45"),
    CountryCode(flag: "🇫🇮", name: "Finland",         dial: "+358"),
    CountryCode(flag: "🇮🇪", name: "Ireland",         dial: "+353"),
    CountryCode(flag: "🇬🇷", name: "Greece",          dial: "+30"),
    CountryCode(flag: "🇷🇴", name: "Romania",         dial: "+40"),
    CountryCode(flag: "🇭🇺", name: "Hungary",         dial: "+36"),
    CountryCode(flag: "🇨🇿", name: "Czech Republic",  dial: "+420"),
    CountryCode(flag: "🇸🇰", name: "Slovakia",        dial: "+421"),
    CountryCode(flag: "🇭🇷", name: "Croatia",         dial: "+385"),
    CountryCode(flag: "🇷🇸", name: "Serbia",          dial: "+381"),
    CountryCode(flag: "🇺🇦", name: "Ukraine",         dial: "+380"),
    CountryCode(flag: "🇷🇺", name: "Russia",          dial: "+7"),
    CountryCode(flag: "🇹🇷", name: "Turkey",          dial: "+90"),
    CountryCode(flag: "🇲🇦", name: "Morocco",         dial: "+212"),
    CountryCode(flag: "🇩🇿", name: "Algeria",         dial: "+213"),
    CountryCode(flag: "🇹🇳", name: "Tunisia",         dial: "+216"),
    CountryCode(flag: "🇸🇳", name: "Senegal",         dial: "+221"),
    CountryCode(flag: "🇨🇮", name: "Côte d'Ivoire",   dial: "+225"),
    CountryCode(flag: "🇬🇭", name: "Ghana",           dial: "+233"),
    CountryCode(flag: "🇳🇬", name: "Nigeria",         dial: "+234"),
    CountryCode(flag: "🇿🇦", name: "South Africa",    dial: "+27"),
    CountryCode(flag: "🇧🇷", name: "Brazil",          dial: "+55"),
    CountryCode(flag: "🇦🇷", name: "Argentina",       dial: "+54"),
    CountryCode(flag: "🇲🇽", name: "Mexico",          dial: "+52"),
    CountryCode(flag: "🇨🇦", name: "Canada",          dial: "+1"),
    CountryCode(flag: "🇦🇺", name: "Australia",       dial: "+61"),
    CountryCode(flag: "🇯🇵", name: "Japan",           dial: "+81"),
    CountryCode(flag: "🇰🇷", name: "South Korea",     dial: "+82"),
    CountryCode(flag: "🇨🇳", name: "China",           dial: "+86"),
    CountryCode(flag: "🇮🇳", name: "India",           dial: "+91"),
    CountryCode(flag: "🇸🇦", name: "Saudi Arabia",    dial: "+966"),
    CountryCode(flag: "🇦🇪", name: "UAE",             dial: "+971"),
    CountryCode(flag: "🇶🇦", name: "Qatar",           dial: "+974"),
]

struct ProfileSetupView: View {
    @Bindable var authManager: AuthManager

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var whatsapp = ""
    @State private var selectedCountry: CountryCode = countryCodes[0]   // France default
    @State private var showCountryPicker = false
    @State private var dateOfBirth: Date = {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }()
    @State private var showDatePicker = false
    @FocusState private var focused: Field?

    private enum Field { case firstName, lastName, whatsapp }

    private var fullWhatsapp: String {
        selectedCountry.dial + whatsapp
    }

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        whatsapp.count >= 6
    }

    private var dobFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: dateOfBirth)
    }

    var body: some View {
        ZStack {
            Color.p6Ink.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    Text("COMPLETE")
                        .font(.custom("BarlowCondensed-Black", size: 42))
                        .kerning(-1)
                        .foregroundColor(.white)
                    Text("YOUR PROFILE")
                        .font(.custom("BarlowCondensed-Black", size: 42))
                        .kerning(-1)
                        .foregroundColor(.white.opacity(0.16))
                        .padding(.bottom, 10)

                    Text("Just a few details to personalise your experience.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 32)

                    // First Name
                    fieldLabel("First name")
                    nameField("John", text: $firstName, thisField: .firstName, next: .lastName)
                        .padding(.bottom, 16)

                    // Last Name
                    fieldLabel("Last name")
                    nameField("Doe", text: $lastName, thisField: .lastName, next: .whatsapp)
                        .padding(.bottom, 16)

                    // WhatsApp
                    fieldLabel("WhatsApp number")
                    whatsappField
                        .padding(.bottom, 16)

                    // Date of birth
                    fieldLabel("Date of birth")
                    dobButton
                    if showDatePicker {
                        DatePicker(
                            "",
                            selection: $dateOfBirth,
                            in: dobRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(.p6Red)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.top, 4)
                    }

                    // Error
                    if let err = authManager.error {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.top, 14)
                    }

                    // CTA
                    P6Button(
                        authManager.isLoading ? "Saving..." : "Continue \u{2192}",
                        gradient: isFormValid && !authManager.isLoading ? .redDeep : nil,
                        disabled: !isFormValid || authManager.isLoading
                    ) {
                        focused = nil
                        Task {
                            await authManager.saveProfile(
                                firstName: firstName.trimmingCharacters(in: .whitespaces),
                                lastName: lastName.trimmingCharacters(in: .whitespaces),
                                whatsapp: fullWhatsapp,
                                dateOfBirth: dateOfBirth
                            )
                        }
                    }
                    .padding(.top, 24)

                    // Legal
                    Text("Your information is kept private and secure.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.22))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 72)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .onTapGesture { focused = nil }
    }

    // MARK: - Field helpers

    @ViewBuilder
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.45))
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private func nameField(_ placeholder: String, text: Binding<String>, thisField: Field, next: Field) -> some View {
        TextField(placeholder, text: text)
            .focused($focused, equals: thisField)
            .submitLabel(.next)
            .onSubmit { focused = next }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
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
    }

    private var whatsappField: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 0) {
                // Country code picker button
                Button {
                    focused = nil
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showCountryPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                            .font(.system(size: 20))
                        Text(selectedCountry.dial)
                            .font(.custom("BarlowCondensed-Bold", size: 16))
                            .foregroundColor(.white)
                        Image(systemName: showCountryPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 12)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                // Vertical divider
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 24)

                // Phone number input
                TextField("612 345 678", text: $whatsapp)
                    .focused($focused, equals: .whatsapp)
                    .keyboardType(.phonePad)
                    .font(.custom("BarlowCondensed-Bold", size: 18))
                    .foregroundColor(.white)
                    .tint(.p6Red)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
            }
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: showCountryPicker ? 12 : 12, style: .continuous)
                    .stroke(showCountryPicker ? Color.p6Red.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Country picker dropdown
            if showCountryPicker {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(countryCodes) { country in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    selectedCountry = country
                                    showCountryPicker = false
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(country.flag).font(.system(size: 20))
                                    Text(country.name)
                                        .font(.custom("BarlowCondensed-Bold", size: 15))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(country.dial)
                                        .font(.custom("BarlowCondensed-Bold", size: 14))
                                        .foregroundColor(.white.opacity(0.4))
                                    if country.id == selectedCountry.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.p6Red)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(country.id == selectedCountry.id ? Color.white.opacity(0.06) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            if country.id != countryCodes.last?.id {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 0.5)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .background(Color(red: 0.13, green: 0.13, blue: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 4)
                .zIndex(10)
            }
        }
    }

    private var dobButton: some View {
        Button {
            focused = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showDatePicker.toggle()
            }
        } label: {
            HStack {
                Text(dobFormatted)
                    .font(.custom("BarlowCondensed-Bold", size: 18))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        showDatePicker ? Color.p6Red.opacity(0.5) : Color.white.opacity(0.12),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var dobRange: PartialRangeThrough<Date> {
        // Must be at least 13 years old
        let max = Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
        return ...max
    }
}
