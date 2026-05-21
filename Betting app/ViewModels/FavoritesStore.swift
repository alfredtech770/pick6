// FavoritesStore.swift
// Persistent set of pick IDs the user has starred.
//
// The match-detail "star" button (top-right of MatchDetailView) toggles
// membership in this set. The Wins / Picks tab reads from this store
// to show every pick the user has favorited, regardless of whether it
// has graded yet.
//
// Persistence: device-local UserDefaults (NOT iCloud-synced — that would
// need NSUbiquitousKeyValueStore). Per-user isolation on a shared device
// is handled by clearing this store on sign-out / account deletion: we
// observe `.pick1UserDidSignOut` (posted by AuthManager) and wipe both the
// in-memory set and the persisted key, so the next user starts clean.
// Trivially swappable for a Supabase `user_favorites` table later.

import Foundation
import Combine

@MainActor
final class FavoritesStore: ObservableObject {

    /// Currently-favorited pick IDs. Mutate via `toggle(_:)` so changes
    /// auto-persist to UserDefaults.
    @Published private(set) var ids: Set<UUID> = []

    private let key = "pick1.favoriteMatchIds.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        // Wipe favorites whenever a user signs out / deletes their account
        // so a different user on the same device never inherits them.
        NotificationCenter.default.addObserver(
            forName: .pick1UserDidSignOut, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clear() }
        }
    }

    /// True iff `id` is in the favorites set.
    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    /// Add or remove `id`. Returns the new state (true = now favorited).
    @discardableResult
    func toggle(_ id: UUID) -> Bool {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        save()
        return ids.contains(id)
    }

    /// Bulk-clear (used by the Wins page's "Clear all" action).
    func clear() {
        ids.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let strings = defaults.array(forKey: key) as? [String] else { return }
        ids = Set(strings.compactMap(UUID.init(uuidString:)))
    }

    private func save() {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }
}
