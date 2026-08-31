// UpdateChecker.swift
// Detects when a newer version of Pick1 is live on the App Store and
// drives the in-app "Update available" banner.
//
// Source of truth is Apple's own iTunes Lookup endpoint
// (https://itunes.apple.com/lookup?bundleId=…) — no backend needed. It
// returns the version string of the build that's CURRENTLY for sale, so
// the moment a new version is approved + released, every older install
// sees it on next launch and gets nudged to update.
//
// Note: a freshly-released version can take a little while to propagate
// through Apple's lookup cache (we bust our own URL cache with a
// timestamp; Apple's edge cache is out of our hands).

import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    /// True once the App Store has a version newer than the running one.
    @Published private(set) var updateAvailable = false
    /// The latest version string on the App Store (for display/debug).
    @Published private(set) var storeVersion: String?

    static let appStoreId = "6761689331"
    private static let bundleId = "com.pick1.app"

    /// Current marketing version of the running build ("1.0.1").
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Fetch the live App Store version and compare. Best-effort — any
    /// failure (offline, throttled, not-yet-indexed) just leaves the
    /// banner hidden. Safe to call on every launch / foreground.
    func check() async {
        // Cache-bust so we don't read a stale lookup right after a release.
        let stamp = Int(Date().timeIntervalSince1970)
        guard let url = URL(string:
            "https://itunes.apple.com/lookup?bundleId=\(Self.bundleId)&_=\(stamp)")
        else { return }
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: req)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let version = results.first?["version"] as? String
            else { return }
            storeVersion = version
            updateAvailable = Self.isNewer(version, than: currentVersion)
        } catch {
            // Stay silent on failure — never block the app on this.
        }
    }

    /// Numeric, component-wise version compare so "1.0.10" > "1.0.9"
    /// and "1.1" > "1.0.5" resolve correctly.
    static func isNewer(_ store: String, than current: String) -> Bool {
        store.compare(current, options: .numeric) == .orderedDescending
    }

    /// Open the Pick1 App Store product page so the user can update.
    func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/id\(Self.appStoreId)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Update banner

/// Slim, dismissible "Update available" banner shown at the top of the
/// app whenever a newer App Store version is live. Localized.
struct UpdateBanner: View {
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "#C6FF34"))

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t(.update_title))
                    .font(.archivo(13, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text(loc.t(.update_body))
                    .font(.archivo(11, weight: .regular))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            VStack(spacing: 6) {
                Button(action: { Haptics.tap(); onUpdate() }) {
                    Text(loc.t(.update_cta))
                        .font(.archivoNarrow(11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#171717"))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: "#C6FF34")))
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text(loc.t(.update_later))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#232323"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#C6FF34").opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
