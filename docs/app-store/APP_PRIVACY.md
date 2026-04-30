# Pick6 — App Privacy Questionnaire

Apple's App Privacy questionnaire walks you through three buckets:

1. **Data Linked to You** — collected and tied to identity
2. **Data Not Linked to You** — collected but anonymous
3. **Data Used to Track You** — used for cross-app/website advertising

Pick6 collects **only what's needed to run the service**. We collect no advertising data and we do not track users across apps or websites. The answers below reflect that.

When the questionnaire asks "Do you collect data from this app?" → answer **Yes**, then walk through the categories.

---

## Data we collect (Linked to the user)

### Contact Info
- [x] **Email Address**
  - Use: **App Functionality** (login via OTP)
  - Linked to user: **Yes**
  - Used for tracking: **No**

### Identifiers
- [x] **User ID**
  - Use: **App Functionality** (associate picks history with account)
  - Linked to user: **Yes**
  - Used for tracking: **No**

### Usage Data
- [x] **Product Interaction**
  - Use: **App Functionality** (knowing which sports a user follows so the home feed filters correctly)
  - Linked to user: **Yes**
  - Used for tracking: **No**

### Purchases
- [x] **Purchase History**
  - Use: **App Functionality** (knowing whether the user has an active Pro subscription)
  - Linked to user: **Yes**
  - Used for tracking: **No**

### Diagnostics (optional — only if you wire crash reporting later)
We do **not** collect diagnostics in v1.0. If you add Sentry / Firebase Crashlytics later, return here and add:
- [ ] **Crash Data** → App Functionality, Linked: No, Tracking: No
- [ ] **Performance Data** → App Functionality, Linked: No, Tracking: No

---

## Data we do NOT collect

Answer **No** for every category below:

| Category | Reasoning |
|---|---|
| Health & Fitness | Not relevant |
| Financial Info | We don't take payments directly — Apple does. We never see card numbers. |
| Location | We don't request location |
| Sensitive Info | None |
| Contacts | We don't access the address book |
| User Content (photos, videos, audio) | None |
| Browsing History | None |
| Search History | None |
| Other Data | None |

Important note on **Financial Info**: subscription purchases go through StoreKit, which means Apple processes the payment — Pick6 never sees, stores, or transmits credit card data. Apple's relationship with the user is what handles all financial PII. So you can answer "No" to this question on the questionnaire even though purchases happen.

---

## Tracking

Question: **Do you or your third-party partners use data from this app to track users?**

Answer: **No**

This means:
- No cross-app advertising
- No data sold or shared for ad targeting
- No SDKs in the binary that track for advertising purposes (no Facebook SDK, no Google AdMob, no Branch, no AppsFlyer, no Adjust, etc.)

You don't need to enable App Tracking Transparency (`NSUserTrackingUsageDescription`) if you answer No here.

---

## Privacy Policy URL

You'll be asked for a URL to your privacy policy. Use the hosted version of `docs/legal/PRIVACY_POLICY.md`. Suggested URL:

```
https://pick6.app/privacy
```

If you don't own pick6.app yet, host on GitHub Pages:

```
https://alfredtech770.github.io/pick6/legal/PRIVACY_POLICY.html
```

Whatever URL you use, keep it stable — Apple checks it on every review.

---

## Privacy Manifest (`PrivacyInfo.xcprivacy`) — required since iOS 17

Apple now requires a `PrivacyInfo.xcprivacy` file in the app bundle declaring required reason APIs. Pick6 uses these API categories:

- `NSPrivacyAccessedAPICategoryUserDefaults` — for `@AppStorage` (`hasFinishedOnboarding`, `selectedSports`)
- `NSPrivacyAccessedAPICategoryFileTimestamp` — none used
- `NSPrivacyAccessedAPICategorySystemBootTime` — none used
- `NSPrivacyAccessedAPICategoryDiskSpace` — none used
- `NSPrivacyAccessedAPICategoryActiveKeyboards` — none used

A minimal `PrivacyInfo.xcprivacy` for Pick6:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeProductInteraction</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePurchaseHistory</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

This file is committed to the repo at `Betting app/PrivacyInfo.xcprivacy` — Xcode automatically bundles it.
