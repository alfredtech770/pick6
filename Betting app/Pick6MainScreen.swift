// Pick6MainScreen.swift
// Main predictions hub. Sport pills → match cards → detail view.
// Usage: Present Pick6MainView() after onboarding completes.

import SwiftUI

// MARK: - Root

// Wrapper to make MatchData usable with .sheet(item:)
struct MatchSelection: Identifiable {
    let match: MatchData
    let sport: Sport
    var id: Int { match.id }
}

public struct Pick6MainView: View {
    @State private var activeSport: Sport = Pick6Data.allSports[0]
    @State private var selectedMatch: MatchSelection? = nil
    @State private var showFavorites = false
    @State private var showProfile = false

    public init() {}

    public var body: some View {
        ZStack {
            // Solid dark charcoal background
            Color(hex: "#151517").ignoresSafeArea()

            MainListView(activeSport: $activeSport, showFavorites: $showFavorites, showProfile: $showProfile) { match in
                selectedMatch = MatchSelection(match: match, sport: activeSport)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFavorites) {
            FavoritesSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMatch) { selection in
            let league = Pick6Data.leagues[selection.sport.id]!
            MatchDetailSheet(
                matches: league.matches,
                initialMatch: selection.match,
                sport: selection.sport
            )
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "#111113"))
        }
    }
}

// MARK: - Favorites Sheet (slides up)

private struct FavoritesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("favoriteMatchIds") private var favoriteIdsString: String = ""
    @State private var selectedFilter: Int = 0

    private let filters = ["Today", "This Week", "All"]

    private var favoriteIds: Set<Int> {
        Set(favoriteIdsString.split(separator: ",").compactMap { Int($0) })
    }

    // Collect all favorited matches from every league
    private var favoriteMatches: [(match: MatchData, sportId: String)] {
        let ids = favoriteIds
        guard !ids.isEmpty else { return [] }
        var results: [(MatchData, String)] = []
        for (sportId, league) in Pick6Data.leagues {
            for match in league.matches where ids.contains(match.id) {
                results.append((match, sportId))
            }
        }
        return results
    }

    var body: some View {
        ZStack {
            Color(hex: "#151517").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                VStack(spacing: 14) {
                    // Top row: logo + close
                    HStack {
                        Spacer()
                        // PICK6 logo
                        HStack(spacing: 0) {
                            Text("PICK")
                                .font(.custom("BarlowCondensed-Black", size: 22))
                                .foregroundColor(.white)
                            Text("6")
                                .font(.custom("BarlowCondensed-Black", size: 22))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.20))
                        }
                    }
                    .overlay(alignment: .leading) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Time filter — Apple Sports style segmented control
                    HStack(spacing: 0) {
                        ForEach(Array(filters.enumerated()), id: \.element) { i, filter in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedFilter = i
                                }
                            } label: {
                                Text(filter)
                                    .font(.system(size: 13, weight: selectedFilter == i ? .bold : .medium))
                                    .foregroundColor(selectedFilter == i ? .white : .white.opacity(0.40))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedFilter == i
                                            ? Color.white.opacity(0.12)
                                            : Color.clear
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                // ── Separator ──
                Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)

                // ── Content ──
                if favoriteMatches.isEmpty {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 40)
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FFD700").opacity(0.10))
                                .frame(width: 72, height: 72)
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#FFD700").opacity(0.30))
                        }
                        Text("NO SAVED PICKS")
                            .font(.system(size: 16, weight: .black))
                            .kerning(2).foregroundColor(.white.opacity(0.5))
                        Text("Tap the star on any match card\nto save it here.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.30))
                            .multilineTextAlignment(.center).lineSpacing(4)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(favoriteMatches, id: \.match.id) { item in
                                MatchCompactPeekCard(match: item.match)
                                    .frame(height: 72)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Profile Sheet (slides up)

private struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager

    private var initials: String {
        let f = authManager.firstName?.prefix(1) ?? "?"
        let l = authManager.lastName?.prefix(1) ?? ""
        return "\(f)\(l)".uppercased()
    }

    var body: some View {
        ZStack {
            Color(hex: "#151517").ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HStack {
                    Spacer()
                    // PICK6 logo
                    HStack(spacing: 0) {
                        Text("PICK")
                            .font(.custom("BarlowCondensed-Black", size: 22))
                            .foregroundColor(.white)
                        Text("6")
                            .font(.custom("BarlowCondensed-Black", size: 22))
                            .foregroundColor(Color(hex: "#22C55E"))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.20))
                    }
                }
                .overlay(alignment: .leading) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#22C55E"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                // ── Separator ──
                Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5)

                // ── Content ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Avatar with initials
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#22C55E").opacity(0.12))
                                .frame(width: 86, height: 86)
                            Circle()
                                .stroke(Color(hex: "#22C55E").opacity(0.25), lineWidth: 2)
                                .frame(width: 86, height: 86)
                            Text(initials)
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                        .padding(.top, 24)

                        // Name
                        VStack(spacing: 6) {
                            Text(authManager.displayName)
                                .font(.system(size: 24, weight: .black))
                                .kerning(1)
                                .foregroundColor(.white)

                            // Member since badge
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: "#22C55E")).frame(width: 5, height: 5)
                                Text("PICK6 MEMBER")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(Color(hex: "#22C55E").opacity(0.7))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color(hex: "#22C55E").opacity(0.08))
                            .clipShape(Capsule())
                        }

                        // Email + WhatsApp
                        VStack(spacing: 8) {
                            if let email = authManager.userEmail {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#22C55E").opacity(0.5))
                                        .frame(width: 20)
                                    Text(email)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.45))
                                    Spacer()
                                }
                            }
                            if let phone = authManager.whatsapp {
                                HStack(spacing: 10) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#22C55E").opacity(0.5))
                                        .frame(width: 20)
                                    Text(phone)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.45))
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .padding(.horizontal, 16)

                        // Settings rows
                        VStack(spacing: 0) {
                            PRowView(icon: "bell.fill",             title: "Notifications")
                            PRowView(icon: "creditcard.fill",       title: "Subscription")
                            PRowView(icon: "globe",                 title: "Preferred Sports")
                            PRowView(icon: "questionmark.circle.fill", title: "Help & Support")
                        }
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .padding(.horizontal, 16)

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                Task { await authManager.signOut() }
                            }
                        } label: {
                            Text("LOG OUT")
                                .font(.system(size: 14, weight: .black))
                                .kerning(2)
                                .foregroundColor(.red.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.red.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Version
                        Text("Pick6 v1.0 · AI Sports Predictions")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.15))
                            .padding(.top, 8)

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PRowView: View {
    let icon: String; let title: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#22C55E").opacity(0.7))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.20))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Header (floating pill)

private struct Pick6Header: View {
    @Binding var showFavorites: Bool
    @Binding var showProfile: Bool
    let activeSport: Sport
    let sports: [Sport]
    let currentIndex: Int

    var body: some View {
        // Outer HStack centers the pill without stretching it
        HStack {
            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 6) {
                // Left: Favorites star (gold)
                Button { showFavorites = true } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .frame(width: 42, height: 54)
                }
                .buttonStyle(.plain)

                // Center: Current sport logo (bigger)
                Group {
                    if !activeSport.logoURL.isEmpty, let url = URL(string: activeSport.logoURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFit().frame(width: 52, height: 52)
                            default:
                                Text(activeSport.icon).font(.system(size: 34))
                            }
                        }
                    } else {
                        Text(activeSport.icon).font(.system(size: 34))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeSport.id)

                // Right: Apple-style profile avatar
                Button { showProfile = true } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#8E8E93"), Color(hex: "#48484A")],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 30, height: 30)
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.90))
                            .offset(y: 2)
                    }
                    .frame(width: 42, height: 54)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(Color(hex: "#2A2A2E"))
                    .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 4)
            )

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

// MARK: - Main List

private struct MainListView: View {
    @Binding var activeSport: Sport
    @Binding var showFavorites: Bool
    @Binding var showProfile: Bool
    let onSelectMatch: (MatchData) -> Void

    @State private var currentIndex: Int = 0
    private let sports = Pick6Data.allSports

    var body: some View {
        VStack(spacing: 0) {
            Pick6Header(
                showFavorites: $showFavorites,
                showProfile: $showProfile,
                activeSport: activeSport,
                sports: sports,
                currentIndex: currentIndex
            )

            // Horizontal sport pager (TabView handles horizontal gestures)
            TabView(selection: $currentIndex) {
                ForEach(Array(sports.enumerated()), id: \.element.id) { index, sport in
                    SportPageContent(sport: sport, onSelectMatch: onSelectMatch)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, newIndex in
                activeSport = sports[newIndex]
            }
        }
        .onAppear {
            if let idx = sports.firstIndex(where: { $0.id == activeSport.id }) {
                currentIndex = idx
            }
        }
    }
}

// MARK: - Sport Page (title + vertical card carousel)

private struct SportPageContent: View {
    let sport: Sport
    let onSelectMatch: (MatchData) -> Void

    var league: LeagueData { Pick6Data.leagues[sport.id]! }

    var body: some View {
        VStack(spacing: 0) {
            // ── Title ──
            VStack(alignment: .leading, spacing: -12) {
                Text(league.name)
                    .font(.system(size: 68, weight: .black))
                    .tracking(-2).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.45)
                Text(league.sub)
                    .font(.system(size: 68, weight: .black))
                    .tracking(-2).foregroundColor(Color.white.opacity(0.10))
                    .lineLimit(1).minimumScaleFactor(0.45)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 10)

            // ── Vertical card carousel — native ScrollView with snap ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(league.matches) { match in
                        Button {
                            onSelectMatch(match)
                        } label: {
                            MatchCard(match: match, visible: true, isF1: sport.id == "f1")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .containerRelativeFrame(.vertical) { length, _ in
                            length * 0.82
                        }
                        .scrollTransition(.animated(.spring(response: 0.35, dampingFraction: 0.78))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.88)
                                .opacity(phase.isIdentity ? 1.0 : 0.45)
                                .rotation3DEffect(
                                    .degrees(phase.value * 12),
                                    axis: (1, 0, 0),
                                    perspective: 0.35
                                )
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollContentBackground(.hidden)
            .safeAreaPadding(.bottom, 0)
            .clipped()
        }
    }
}

// MARK: - Compact Peek Card (logos + VS only)

private struct MatchCompactPeekCard: View {
    let match: MatchData

    var body: some View {
        ZStack {
            // Base
            Color(hex: "#232325")

            // Subtle team color hints from each side
            LinearGradient(
                colors: [match.home.hex.opacity(0.20), .clear],
                startPoint: .leading,
                endPoint: UnitPoint(x: 0.42, y: 0.5)
            )
            LinearGradient(
                colors: [match.away.hex.opacity(0.20), .clear],
                startPoint: .trailing,
                endPoint: UnitPoint(x: 0.58, y: 0.5)
            )

            HStack(spacing: 0) {
                // Home logo + name
                HStack(spacing: 10) {
                    Pick6TeamLogo(team: match.home, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(match.home.name.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.40))
                            .lineLimit(1)
                        Text(match.home.sub.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center: VS or live score
                Group {
                    if match.isLive {
                        Text("\(match.liveHomeScore)–\(match.liveAwayScore)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                    } else {
                        Text("VS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.28))
                    }
                }
                .frame(width: 48)

                // Away logo + name
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(match.away.name.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.40))
                            .lineLimit(1)
                        Text(match.away.sub.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Pick6TeamLogo(team: match.away, size: 40)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Match Peek Row (Apple Sports compact list style)

private struct MatchPeekRow: View {
    let match: MatchData

    var body: some View {
        HStack(spacing: 0) {
            // Home
            HStack(spacing: 10) {
                Pick6TeamLogo(team: match.home, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(match.home.sub.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(match.home.name.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.38))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center: score or kickoff
            Group {
                if match.isLive {
                    HStack(alignment: .center, spacing: 5) {
                        Text("\(match.liveHomeScore)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        Text("–")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.38))
                        Text("\(match.liveAwayScore)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 0) {
                        Text("\(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.white.opacity(0.75))
                        Text("\(match.date) \(match.month.prefix(3).uppercased())")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.32))
                    }
                }
            }
            .frame(width: 72)

            // Away
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(match.away.sub.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(match.away.name.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.38))
                        .lineLimit(1)
                }
                Pick6TeamLogo(team: match.away, size: 34)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(hex: "#2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Match Card (Apple Sports style)

private struct MatchCard: View {
    let match: MatchData
    let visible: Bool
    var isF1: Bool = false

    @State private var livePulse = false
    @State private var barFill: CGFloat = 0

    @AppStorage("favoriteMatchIds") private var favoriteIdsString: String = ""

    private var isFavorited: Bool {
        favoriteIdsString.split(separator: ",").compactMap { Int($0) }.contains(match.id)
    }
    private func toggleFavorite() {
        var ids = Set(favoriteIdsString.split(separator: ",").compactMap { Int($0) })
        if ids.contains(match.id) { ids.remove(match.id) } else { ids.insert(match.id) }
        favoriteIdsString = ids.map(String.init).joined(separator: ",")
    }

    private var homeOdds: String { match.homePct > 0 ? String(format: "%.2f", 100.0 / Double(match.homePct)) : "–" }
    private var drawOdds: String { match.drawPct > 0 ? String(format: "%.2f", 100.0 / Double(match.drawPct)) : "–" }
    private var awayOdds: String { match.awayPct > 0 ? String(format: "%.2f", 100.0 / Double(match.awayPct)) : "–" }

    private var pickedPct: Int {
        switch match.aiPick { case "home": return match.homePct; case "away": return match.awayPct; default: return match.drawPct }
    }
    private var potentialWin: String {
        guard pickedPct > 0 else { return "–" }
        return String(format: "$%.0f", 10.0 * 100.0 / Double(pickedPct))
    }
    private var pickedTeamName: String {
        switch match.aiPick {
        case "home": return "\(match.home.name) \(match.home.sub)"
        case "away": return "\(match.away.name) \(match.away.sub)"
        default: return "Draw"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Base: Apple Sports dark gray
            Color(hex: "#1C1C1E")

            // Home team color gradient
            LinearGradient(
                colors: [match.home.hex.opacity(isF1 ? 0.25 : 0.22), match.home.hex.opacity(0)],
                startPoint: isF1 ? .top : .topLeading,
                endPoint: isF1 ? UnitPoint(x: 0.5, y: 0.35) : UnitPoint(x: 0.38, y: 0.28)
            )

            // Away team color gradient (hidden for F1)
            LinearGradient(
                colors: [match.away.hex.opacity(isF1 ? 0 : 0.22), match.away.hex.opacity(0)],
                startPoint: .topTrailing,
                endPoint: UnitPoint(x: 0.62, y: 0.28)
            )

            VStack(spacing: 0) {
                // ── Teams row ──
                if isF1 {
                    // Single driver layout for F1
                    VStack(spacing: 12) {
                        Pick6TeamLogo(team: match.home, size: 96)
                            .shadow(color: match.home.hex.opacity(0.30), radius: 14, x: 0, y: 6)
                        VStack(spacing: 3) {
                            Text(match.home.name.uppercased())
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.50))
                            Text(match.home.sub.uppercased())
                                .font(.system(size: 24, weight: .black))
                                .tracking(-0.5)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        // Team name pill
                        Text(f1TeamName(for: match.home.abbr).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(match.home.hex)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(match.home.hex.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        // Home team
                        VStack(spacing: 10) {
                            Pick6TeamLogo(team: match.home, size: 76)
                                .shadow(color: match.home.hex.opacity(0.20), radius: 10, x: -4, y: 4)
                            VStack(spacing: 2) {
                                Text(match.home.name.uppercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.45))
                                Text(match.home.sub.uppercased())
                                    .font(.system(size: 18, weight: .black))
                                    .tracking(-0.5)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Center: kickoff / live score
                        VStack(spacing: 4) {
                            Spacer().frame(height: 8)
                            if match.isLive {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#FF3B30")).frame(width: 6, height: 6)
                                        .opacity(livePulse ? 0.25 : 1)
                                    Text("LIVE · \(match.liveMinute)'")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(Color(hex: "#FF3B30"))
                                }
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { livePulse = true }
                                }
                                Text("\(match.liveHomeScore) – \(match.liveAwayScore)")
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            } else {
                                Text("\(match.date) \(match.month.prefix(3).uppercased())")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.36))
                                Text("\(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)")
                                    .font(.system(size: 26, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("VS")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                        .frame(width: 90)

                        // Away team
                        VStack(spacing: 10) {
                            Pick6TeamLogo(team: match.away, size: 76)
                                .shadow(color: match.away.hex.opacity(0.20), radius: 10, x: 4, y: 4)
                            VStack(spacing: 2) {
                                Text(match.away.name.uppercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.45))
                                Text(match.away.sub.uppercased())
                                    .font(.system(size: 18, weight: .black))
                                    .tracking(-0.5)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }

                Spacer(minLength: 0)

                // ── Separator ──
                Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)

                Spacer(minLength: 0)

                // ── AI Confidence ──
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(match.aiConf)%")
                        .font(.system(size: 52, weight: .black))
                        .tracking(-1)
                        .foregroundColor(.white)
                    Text("AI CONFIDENCE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // ── Confidence bar ──
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                        Capsule()
                            .fill(Color(hex: "#22C55E"))
                            .frame(width: geo.size.width * barFill * CGFloat(match.aiConf) / 100, height: 8)
                    }
                }
                .frame(height: 10)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)
                .onAppear {
                    barFill = 0
                    withAnimation(.easeOut(duration: 0.9).delay(0.15)) { barFill = 1 }
                }

                Spacer(minLength: 0)

                // ── Odds pills ──
                if isF1 {
                    // F1: show predicted position range
                    HStack(spacing: 8) {
                        oddsPill(label: "PODIUM", value: "\(match.homePct)%", highlight: true, color: match.home.hex)
                        oddsPill(label: "TOP 5", value: "\(max(match.homePct - 10, 20))%", highlight: false, color: .white)
                        oddsPill(label: "TOP 10", value: "\(max(match.homePct + 8, 40))%", highlight: false, color: .white)
                    }
                    .padding(.horizontal, 20)
                } else {
                    HStack(spacing: 8) {
                        oddsPill(label: "WIN",  value: homeOdds, highlight: match.aiPick == "home", color: match.home.hex)
                        if match.drawPct > 0 {
                            oddsPill(label: "DRAW", value: drawOdds, highlight: match.aiPick == "draw", color: .white)
                        }
                        oddsPill(label: "LOSS", value: awayOdds, highlight: match.aiPick == "away", color: match.away.hex)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 0)

                // ── Separator ──
                Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)

                // ── Potential win ──
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#22C55E"))
                        Text(isF1 ? "\(match.home.sub.uppercased()) PREDICTED FINISH" : "IF \(pickedTeamName.uppercased()) WINS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.3)
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    if isF1 {
                        // Show predicted position
                        Text("P\(f1PredictedPosition(conf: match.aiConf))")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Color(hex: "#22C55E"))
                    } else {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("$10").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.32))
                            Text("→").font(.system(size: 10)).foregroundColor(.white.opacity(0.22))
                            Text(potentialWin).font(.system(size: 22, weight: .black)).foregroundColor(Color(hex: "#22C55E"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button { toggleFavorite() } label: {
                Image(systemName: isFavorited ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isFavorited ? Color(hex: "#FFD700") : .white.opacity(0.5))
                    .padding(14)
            }
            .buttonStyle(.plain)
        }
        .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 12)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 32)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: visible)
    }

    @ViewBuilder
    private func oddsPill(label: String, value: String, highlight: Bool, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(highlight ? color : .white.opacity(0.35))
            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(highlight ? .white : .white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(highlight ? color.opacity(0.15) : .white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(highlight ? color.opacity(0.4) : .clear, lineWidth: 1))
    }

    // F1 team name lookup by driver abbreviation
    private func f1TeamName(for abbr: String) -> String {
        switch abbr {
        case "VER", "TSU": return "Red Bull Racing"
        case "NOR", "PIA": return "McLaren"
        case "LEC", "HAM": return "Ferrari"
        case "RUS", "ANT": return "Mercedes"
        case "SAI", "ALB": return "Williams"
        case "ALO", "STR": return "Aston Martin"
        default: return "F1"
        }
    }

    // Convert AI confidence to predicted position
    private func f1PredictedPosition(conf: Int) -> String {
        switch conf {
        case 80...100: return "1"
        case 70...79: return "2"
        case 60...69: return "3"
        case 55...59: return "4"
        case 50...54: return "5"
        case 45...49: return "6"
        case 40...44: return "7"
        case 35...39: return "8"
        case 30...34: return "9"
        default: return "10"
        }
    }

}

// MARK: - Team Logo (Real ESPN logos with fallback)

private struct Pick6TeamLogo: View {
    let team: Team
    let size: CGFloat

    var body: some View {
        if !team.logoURL.isEmpty, let url = URL(string: team.logoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .frame(width: size, height: size)
                case .failure:
                    fallbackBadge
                default:
                    fallbackBadge.opacity(0.4)
                }
            }
        } else {
            fallbackBadge
        }
    }

    private var fallbackBadge: some View {
        ZStack {
            Circle()
                .fill(team.hex)
                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
            Text(team.abbr)
                .font(.custom("BarlowCondensed-Black", size: size * 0.3))
                .foregroundColor(team.kitColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Team Badge

struct TeamBadge: View {
    let team: Team
    let size: CGFloat

    init(hex: Color, kitColor: Color, abbr: String, size: CGFloat) {
        self.team = Team(name: "", sub: "", abbr: abbr, hex: hex, kitColor: kitColor, form: [], goalsPerGame: 0)
        self.size = size
    }

    init(team: Team, size: CGFloat) {
        self.team = team
        self.size = size
    }

    var body: some View {
        Pick6TeamLogo(team: team, size: size)
    }
}

// MARK: - Match Detail Sheet (Premium glassmorphism style)

private struct MatchDetailSheet: View {
    let matches: [MatchData]
    let initialMatch: MatchData
    let sport: Sport

    @State private var currentMatchIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Solid dark charcoal background
            Color(hex: "#111113").ignoresSafeArea()

            TabView(selection: $currentMatchIndex) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    MatchDetailPage(match: match, sport: sport, totalMatches: matches.count, currentIndex: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            if let idx = matches.firstIndex(where: { $0.id == initialMatch.id }) {
                currentMatchIndex = idx
            }
        }
    }
}

// MARK: - Match Detail Page

private struct MatchDetailPage: View {
    let match: MatchData
    let sport: Sport
    let totalMatches: Int
    let currentIndex: Int

    @State private var statsIn = false
    @State private var ringProgress: Double = 0
    @State private var showBookmakers = false
    @State private var confValue = 0
    @State private var homeValue = 0
    @State private var awayValue = 0
    @State private var drawValue = 0
    @State private var pulseOpacity: Double = 1.0

    private let white87 = Color.white.opacity(0.87)
    private let white50 = Color.white.opacity(0.5)
    private let white25 = Color.white.opacity(0.25)
    private let white10 = Color.white.opacity(0.10)
    private let glassBg  = Color(hex: "#1E1E22")
    private let glassBrd = Color.white.opacity(0.08)

    var winnerName: String {
        switch match.aiPick {
        case "home": return "\(match.home.name) \(match.home.sub)"
        case "away": return "\(match.away.name) \(match.away.sub)"
        default: return "DRAW"
        }
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(glassBg)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(glassBrd, lineWidth: 0.5))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("BarlowCondensed-Black", size: 14))
            .kerning(1.8)
            .foregroundColor(white87)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Page dots ──
                    HStack(spacing: 6) {
                        ForEach(0..<totalMatches, id: \.self) { i in
                            Capsule()
                                .fill(i == currentIndex ? Color.white : Color.white.opacity(0.2))
                                .frame(width: i == currentIndex ? 18 : 6, height: 4)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    // Sport label
                    Text(sport.label)
                        .font(.custom("BarlowCondensed-Bold", size: 11))
                        .kerning(1.5)
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.bottom, 12)

                    // ── Apple Sports score header ──
                    VStack(spacing: 0) {
                        ZStack {
                            // Subtle team color bleed
                            HStack(spacing: 0) {
                                LinearGradient(colors: [match.home.hex.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                                LinearGradient(colors: [.clear, match.away.hex.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            VStack(spacing: 12) {
                                // Status line
                                if match.isLive {
                                    HStack(spacing: 5) {
                                        Circle().fill(Color(hex: "#FF3B30")).frame(width: 6, height: 6).opacity(pulseOpacity)
                                        Text("LIVE · \(match.liveMinute)'")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(1)
                                            .foregroundColor(Color(hex: "#FF3B30"))
                                    }
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulseOpacity = 0.3 }
                                    }
                                } else {
                                    Text("\(match.date) \(match.month.prefix(3).uppercased()) · \(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(1)
                                        .foregroundColor(white50)
                                }

                                // Main score row
                                HStack(alignment: .center, spacing: 0) {
                                    // Home team
                                    VStack(spacing: 8) {
                                        Pick6TeamLogo(team: match.home, size: 62)
                                        VStack(spacing: 2) {
                                            Text(match.home.name.uppercased())
                                                .font(.system(size: 10, weight: .medium))
                                                .tracking(0.8)
                                                .foregroundColor(white50)
                                            Text(match.home.sub.uppercased())
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(white87)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Score
                                    VStack(spacing: 4) {
                                        if match.isLive {
                                            HStack(alignment: .center, spacing: 8) {
                                                Text("\(match.liveHomeScore)")
                                                    .font(.system(size: 56, weight: .black))
                                                    .foregroundColor(.white)
                                                Text("–")
                                                    .font(.system(size: 28, weight: .thin))
                                                    .foregroundColor(white25)
                                                Text("\(match.liveAwayScore)")
                                                    .font(.system(size: 56, weight: .black))
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            Text("VS")
                                                .font(.system(size: 13, weight: .black))
                                                .tracking(3)
                                                .foregroundColor(white25)
                                            Text("\(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)")
                                                .font(.system(size: 42, weight: .black))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 140)

                                    // Away team
                                    VStack(spacing: 8) {
                                        Pick6TeamLogo(team: match.away, size: 62)
                                        VStack(spacing: 2) {
                                            Text(match.away.name.uppercased())
                                                .font(.system(size: 10, weight: .medium))
                                                .tracking(0.8)
                                                .foregroundColor(white50)
                                            Text(match.away.sub.uppercased())
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(white87)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                // Live progress bar
                                if match.isLive && match.liveMinute > 0 {
                                    VStack(spacing: 4) {
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(.white.opacity(0.08)).frame(height: 3)
                                                Capsule()
                                                    .fill(Color(hex: "#22C55E"))
                                                    .frame(width: geo.size.width * CGFloat(match.liveMinute) / 90.0, height: 3)
                                            }
                                        }
                                        .frame(height: 3)
                                        HStack {
                                            Text("0'").font(.system(size: 9, weight: .medium)).foregroundColor(white25)
                                            Spacer()
                                            Text("HT").font(.system(size: 9, weight: .medium)).foregroundColor(white25)
                                            Spacer()
                                            Text("90'").font(.system(size: 9, weight: .medium)).foregroundColor(white25)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 16)
                        }
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                    // ── Sport field visual ──
                    SportFieldView(sportId: sport.id)
                        .frame(height: 154)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                    // ── Action row ──
                    HStack(spacing: 10) {
                        // Bookmark
                        DetailActionButton(icon: "bookmark", label: nil)
                        // Live / Not started pill
                        if match.isLive {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: "#FF3B30")).frame(width: 7, height: 7)
                                    .opacity(pulseOpacity)
                                Text("LIVE").font(.custom("BarlowCondensed-Black", size: 13)).kerning(1.5).foregroundColor(.white)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 11)
                            .background(Color(hex: "#FF3B30").opacity(0.18))
                            .clipShape(Capsule())
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulseOpacity = 0.3 }
                            }
                        } else {
                            Text("PREVIEW")
                                .font(.custom("BarlowCondensed-Black", size: 13)).kerning(1.5).foregroundColor(white50)
                                .padding(.horizontal, 20).padding(.vertical, 11)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        // 1X2 / BET
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showBookmakers.toggle() }
                        } label: {
                            Text(showBookmakers ? "CLOSE" : "1X2")
                                .font(.custom("BarlowCondensed-Black", size: 13)).kerning(1.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20).padding(.vertical, 11)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        // Share
                        DetailActionButton(icon: "square.and.arrow.up", label: nil)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                    // ── WHO WILL WIN? ──
                    glassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionLabel("WHO WILL WIN?")
                            HStack(spacing: 0) {
                                WinRingView(pct: homeValue, label: "W", caption: match.home.abbr, color: Color(hex: "#34C759"), progress: ringProgress)
                                    .frame(maxWidth: .infinity)
                                if match.drawPct > 0 {
                                    WinRingView(pct: drawValue, label: "D", caption: "DRAW", color: Color(hex: "#8E8E93"), progress: ringProgress)
                                        .frame(maxWidth: .infinity)
                                }
                                WinRingView(pct: awayValue, label: "L", caption: match.away.abbr, color: Color(hex: "#FF3B30"), progress: ringProgress)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // ── AI PREDICTION ──
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(hex: "#2A2A2E")).frame(width: 32, height: 32)
                                    Image(systemName: "sparkles").font(.system(size: 13)).foregroundColor(Color(hex: "#22C55E"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI PREDICTION").font(.custom("BarlowCondensed-Bold", size: 8)).kerning(2).foregroundColor(white50)
                                    Text("PICK: \(winnerName.uppercased())").font(.custom("BarlowCondensed-Black", size: 19)).foregroundColor(white87)
                                }
                                Spacer()
                                VStack(spacing: 1) {
                                    Text("\(confValue)%").font(.custom("BarlowCondensed-Black", size: 22)).foregroundColor(.white)
                                    Text("CONF").font(.custom("BarlowCondensed-Bold", size: 7)).kerning(1.5).foregroundColor(white50)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color(hex: "#2A2A2E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Text(match.aiReason)
                                .font(.custom("BarlowCondensed-Bold", size: 13))
                                .foregroundColor(white87).lineSpacing(4)
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    // ── LAST 5 GAMES ──
                    glassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                sectionLabel("LAST 5 GAMES")
                                Spacer()
                                Text("SEE ALL").font(.custom("BarlowCondensed-Bold", size: 10)).kerning(1.5).foregroundColor(white50)
                            }
                            DetailFormRow(team: match.home, statsIn: statsIn)
                            Divider().background(Color.white.opacity(0.06))
                            DetailFormRow(team: match.away, statsIn: statsIn)
                        }
                    }

                    // ── HEAD TO HEAD ──
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("HEAD TO HEAD")
                            ForEach(match.h2h, id: \.date) { g in
                                HStack {
                                    Text(g.date)
                                        .font(.custom("BarlowCondensed-Bold", size: 12)).foregroundColor(white50)
                                        .frame(width: 54, alignment: .leading)
                                    Spacer()
                                    HStack(spacing: 12) {
                                        Pick6TeamLogo(team: match.home, size: 24)
                                        Text(g.score)
                                            .font(.custom("BarlowCondensed-Black", size: 20)).foregroundColor(white87)
                                        Pick6TeamLogo(team: match.away, size: 24)
                                    }
                                    Spacer()
                                    Text(g.outcome == "home" ? match.home.abbr : g.outcome == "away" ? match.away.abbr : "DRAW")
                                        .font(.custom("BarlowCondensed-Black", size: 11)).kerning(1).foregroundColor(white87)
                                        .opacity(g.outcome == "draw" ? 0.4 : 1)
                                        .frame(width: 54, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5), alignment: .bottom)
                            }
                            // Record summary
                            let homeWins = match.h2h.filter { $0.outcome == "home" }.count
                            let draws    = match.h2h.filter { $0.outcome == "draw" }.count
                            let awayWins = match.h2h.filter { $0.outcome == "away" }.count
                            HStack(spacing: 0) {
                                ForEach([(match.home.abbr, homeWins, match.home.hex),
                                         ("DRAW", draws, Color(hex: "#8E8E93")),
                                         (match.away.abbr, awayWins, match.away.hex)], id: \.0) { lbl, val, col in
                                    VStack(spacing: 4) {
                                        Text("\(val)").font(.custom("BarlowCondensed-Black", size: 32)).foregroundColor(.white)
                                        Text(lbl).font(.custom("BarlowCondensed-Bold", size: 9)).kerning(1.2).foregroundColor(white50)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.top, 6)
                        }
                    }

                    // ── LINEUPS ──
                    glassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("LINEUPS")
                            ForEach([(match.home, match.homeLineup), (match.away, match.awayLineup)], id: \.0.abbr) { team, lineup in
                                HStack(spacing: 8) {
                                    Pick6TeamLogo(team: team, size: 22)
                                    Text("\(team.name) \(team.sub)")
                                        .font(.custom("BarlowCondensed-Black", size: 13)).kerning(0.5).foregroundColor(white87)
                                }
                                .padding(.bottom, 6)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(lineup.enumerated()), id: \.offset) { idx, playerName in
                                            PlayerSilhouette(name: playerName, number: idx + 1, cardBg: glassBg, dark: white87)
                                        }
                                    }
                                    .padding(.bottom, 4)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }

                    // ── LIVE TIMELINE ──
                    if match.isLive {
                        glassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionLabel("MATCH TIMELINE")
                                LiveTimelineDark(match: match)
                            }
                        }
                    }

                    Spacer().frame(height: 110)
                }
            }

            // ── Bookmakers + BET NOW ──
            VStack(spacing: 0) {
                if showBookmakers {
                    VStack(spacing: 0) {
                        ForEach(Array(["Betclic","Winamax","Unibet","PMU","Bwin"].enumerated()), id: \.offset) { i, name in
                            HStack {
                                Text(name).font(.custom("BarlowCondensed-Black", size: 15)).kerning(1.5).foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 12)).foregroundColor(white50)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            if i < 4 { Divider().background(Color.white.opacity(0.08)) }
                        }
                    }
                    .background(Color(hex: "#2A2A2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 10)
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showBookmakers.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Text(showBookmakers ? "CLOSE" : "BET NOW")
                            .font(.custom("BarlowCondensed-Black", size: 16)).kerning(4).foregroundColor(.white)
                        Image(systemName: showBookmakers ? "xmark" : "arrow.right")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            .rotationEffect(.degrees(showBookmakers ? 0 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "#22C55E"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
            .background(
                LinearGradient(colors: [Color.clear, Color(hex: "#111113")], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130).ignoresSafeArea(),
                alignment: .bottom
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { statsIn = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.32)) { ringProgress = 1 }
            animateCount(target: match.aiConf,  binding: { confValue = $0 }, delay: 0.30)
            animateCount(target: match.homePct, binding: { homeValue = $0 }, delay: 0.35)
            animateCount(target: match.drawPct, binding: { drawValue = $0 }, delay: 0.38)
            animateCount(target: match.awayPct, binding: { awayValue = $0 }, delay: 0.40)
        }
    }

    private func animateCount(target: Int, binding: @escaping (Int) -> Void, delay: Double) {
        let steps = 30
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i) * 0.033) {
                let t = Double(i) / Double(steps)
                binding(Int((1 - pow(1 - t, 3)) * Double(target)))
            }
        }
    }
}

// MARK: - Sport Field Canvas

private struct SportFieldView: View {
    let sportId: String

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            switch sportId {
            case "nba", "basketball": drawBasketball(ctx, w, h)
            case "tennis":            drawTennis(ctx, w, h)
            case "nfl", "football":   drawAmericanFootball(ctx, w, h)
            default:                  drawSoccer(ctx, w, h)
            }
        }
    }

    private func drawSoccer(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        // Grass
        ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)), with: .color(Color(hex:"#1E6B2E")))
        for i in 0..<7 {
            let sw = w/7
            if i%2==0 { ctx.fill(Path(CGRect(x:CGFloat(i)*sw,y:0,width:sw,height:h)), with: .color(Color(hex:"#1A6129").opacity(0.8))) }
        }
        let m: CGFloat = 10
        func stroke(_ path: Path) { ctx.stroke(path, with: .color(.white.opacity(0.75)), lineWidth: 1.5) }
        // Outer
        stroke(Path(CGRect(x:m,y:m,width:w-m*2,height:h-m*2)))
        // Center line
        var cl = Path(); cl.move(to:.init(x:w/2,y:m)); cl.addLine(to:.init(x:w/2,y:h-m)); stroke(cl)
        // Center circle
        var cc = Path(); cc.addEllipse(in: CGRect(x:w/2-h*0.22,y:h/2-h*0.22,width:h*0.44,height:h*0.44)); stroke(cc)
        var cd = Path(); cd.addEllipse(in:CGRect(x:w/2-3,y:h/2-3,width:6,height:6)); ctx.fill(cd, with:.color(.white.opacity(0.8)))
        // Penalty areas
        let paw=w*0.2, pah=h*0.6
        stroke(Path(CGRect(x:m,y:h/2-pah/2,width:paw,height:pah)))
        stroke(Path(CGRect(x:w-m-paw,y:h/2-pah/2,width:paw,height:pah)))
        // Goals
        let gaw=w*0.03, gah=h*0.28
        ctx.fill(Path(CGRect(x:m-gaw,y:h/2-gah/2,width:gaw,height:gah)), with:.color(.white.opacity(0.3)))
        ctx.fill(Path(CGRect(x:w-m,y:h/2-gah/2,width:gaw,height:gah)), with:.color(.white.opacity(0.3)))
    }

    private func drawBasketball(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)), with:.color(Color(hex:"#8B4513")))
        for i in 0..<6 {
            let sw=w/6
            if i%2==0 { ctx.fill(Path(CGRect(x:CGFloat(i)*sw,y:0,width:sw,height:h)), with:.color(Color(hex:"#7A3B11").opacity(0.6))) }
        }
        let m:CGFloat=10
        func stroke(_ p:Path) { ctx.stroke(p, with:.color(.white.opacity(0.7)), lineWidth:1.5) }
        stroke(Path(CGRect(x:m,y:m,width:w-m*2,height:h-m*2)))
        var cl=Path(); cl.move(to:.init(x:w/2,y:m)); cl.addLine(to:.init(x:w/2,y:h-m)); stroke(cl)
        var cc=Path(); cc.addEllipse(in:CGRect(x:w/2-h*0.2,y:h/2-h*0.2,width:h*0.4,height:h*0.4)); stroke(cc)
        // Keys
        let kw=w*0.22, kh=h*0.75
        stroke(Path(CGRect(x:m,y:h/2-kh/2,width:kw,height:kh)))
        stroke(Path(CGRect(x:w-m-kw,y:h/2-kh/2,width:kw,height:kh)))
        var arc1=Path(); arc1.addEllipse(in:CGRect(x:m+kw-h*0.12,y:h/2-h*0.12,width:h*0.24,height:h*0.24)); stroke(arc1)
        var arc2=Path(); arc2.addEllipse(in:CGRect(x:w-m-kw-h*0.12,y:h/2-h*0.12,width:h*0.24,height:h*0.24)); stroke(arc2)
    }

    private func drawTennis(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)), with:.color(Color(hex:"#1565C0")))
        let m:CGFloat=10
        func stroke(_ p:Path) { ctx.stroke(p, with:.color(.white.opacity(0.8)), lineWidth:1.5) }
        stroke(Path(CGRect(x:m,y:m,width:w-m*2,height:h-m*2)))
        var sl=Path(); sl.move(to:.init(x:w/2,y:m)); sl.addLine(to:.init(x:w/2,y:h-m)); stroke(sl)
        let sy=h*0.22
        var st=Path(); st.move(to:.init(x:m,y:sy)); st.addLine(to:.init(x:w-m,y:sy)); stroke(st)
        var sb=Path(); sb.move(to:.init(x:m,y:h-sy)); sb.addLine(to:.init(x:w-m,y:h-sy)); stroke(sb)
        var net=Path(); net.move(to:.init(x:w/2,y:m)); net.addLine(to:.init(x:w/2,y:h-m))
        ctx.stroke(net, with:.color(.white.opacity(0.9)), lineWidth:3)
    }

    private func drawAmericanFootball(_ ctx: GraphicsContext, _ w: CGFloat, _ h: CGFloat) {
        ctx.fill(Path(CGRect(x:0,y:0,width:w,height:h)), with:.color(Color(hex:"#2E7D32")))
        let m:CGFloat=10
        func stroke(_ p:Path) { ctx.stroke(p, with:.color(.white.opacity(0.6)), lineWidth:1.2) }
        stroke(Path(CGRect(x:m,y:m,width:w-m*2,height:h-m*2)))
        let zones=10
        for i in 1..<zones {
            let x=m+(w-m*2)/CGFloat(zones)*CGFloat(i)
            var l=Path(); l.move(to:.init(x:x,y:m)); l.addLine(to:.init(x:x,y:h-m)); stroke(l)
        }
        // End zones
        ctx.fill(Path(CGRect(x:m,y:m,width:(w-m*2)/10,height:h-m*2)), with:.color(.white.opacity(0.08)))
        ctx.fill(Path(CGRect(x:w-m-(w-m*2)/10,y:m,width:(w-m*2)/10,height:h-m*2)), with:.color(.white.opacity(0.08)))
    }
}

// MARK: - Win Ring

private struct WinRingView: View {
    let pct: Int
    let label: String
    let caption: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: CGFloat(progress) * CGFloat(pct) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                    .animation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.2), value: progress)
                ZStack {
                    Circle().fill(color).frame(width: 34, height: 34)
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            Text("\(pct)%")
                .font(.custom("BarlowCondensed-Black", size: 18))
                .foregroundColor(.white)
            Text(caption)
                .font(.custom("BarlowCondensed-Bold", size: 11))
                .foregroundColor(Color.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Detail Form Row

private struct DetailFormRow: View {
    let team: Team
    let statsIn: Bool

    private func resultColor(_ r: FormResult) -> Color {
        switch r {
        case .win:    return Color(hex: "#34C759")
        case .loss:   return Color(hex: "#FF3B30")
        case .podium: return Color(hex: "#FFD60A")
        default:      return Color(hex: "#8E8E93")
        }
    }

    var wins: Int { team.form.filter { $0 == .win || $0 == .podium }.count }

    var body: some View {
        HStack(spacing: 10) {
            Pick6TeamLogo(team: team, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(team.name).font(.custom("BarlowCondensed-Black", size: 14)).foregroundColor(.white).lineLimit(1)
                Text(team.sub).font(.custom("BarlowCondensed-Bold", size: 10)).foregroundColor(Color.white.opacity(0.4)).lineLimit(1)
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(Array(team.form.enumerated()), id: \.offset) { j, r in
                    ZStack {
                        Circle().fill(resultColor(r)).frame(width: 32, height: 32)
                        Text(r.shortLabel)
                            .font(.custom("BarlowCondensed-Black", size: 12))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(statsIn ? 1 : 0.01)
                    .animation(.spring(response: 0.38, dampingFraction: 0.6).delay(0.15 + Double(j) * 0.07), value: statsIn)
                }
            }
            Text("\(wins)/5")
                .font(.custom("BarlowCondensed-Black", size: 13))
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.leading, 6)
        }
    }
}

// MARK: - Detail Action Button

private struct DetailActionButton: View {
    let icon: String
    let label: String?
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08)).frame(width: 42, height: 42)
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(Color.white.opacity(0.7))
        }
    }
}

// MARK: - Live Timeline (Dark theme)

private struct LiveTimelineDark: View {
    let match: MatchData

    struct LiveEvent: Identifiable {
        let id = UUID()
        let minute: Int
        let icon: String
        let title: String
        let detail: String
        let isKey: Bool
    }

    var events: [LiveEvent] {
        [
            LiveEvent(minute: 3,  icon: "⚽", title: "GOAL", detail: "\(match.home.abbr) — Early opener from a corner kick", isKey: true),
            LiveEvent(minute: 12, icon: "🟡", title: "YELLOW CARD", detail: "\(match.away.abbr) — Tactical foul in midfield", isKey: false),
            LiveEvent(minute: 23, icon: "📊", title: "POSSESSION", detail: "\(match.home.abbr) 42% — \(match.away.abbr) 58%", isKey: false),
            LiveEvent(minute: 34, icon: "⚽", title: "GOAL", detail: "\(match.away.abbr) — Equalizer! Low driven shot", isKey: true),
            LiveEvent(minute: 45, icon: "⏱", title: "HALF TIME", detail: "1 – 1 · xG: \(match.home.abbr) 0.8 – \(match.away.abbr) 1.2", isKey: false),
            LiveEvent(minute: 52, icon: "🔄", title: "SUBSTITUTION", detail: "\(match.home.abbr) — Fresh legs in midfield", isKey: false),
            LiveEvent(minute: 61, icon: "⚽", title: "GOAL", detail: "\(match.away.abbr) — Clinical counter-attack", isKey: true),
            LiveEvent(minute: 67, icon: "📈", title: "AI UPDATE", detail: "Win probability shifted: \(match.away.abbr) now at \(match.aiConf)%", isKey: true),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(event.minute)'")
                        .font(.custom("BarlowCondensed-Black", size: 14))
                        .foregroundColor(event.isKey ? Color.white.opacity(0.87) : Color.white.opacity(0.4))
                        .frame(width: 30, alignment: .trailing)

                    VStack(spacing: 0) {
                        Circle()
                            .fill(event.isKey ? Color.white.opacity(0.87) : Color.white.opacity(0.2))
                            .frame(width: event.isKey ? 10 : 7, height: event.isKey ? 10 : 7)
                        if event.minute < 67 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(event.icon).font(.system(size: 12))
                            Text(event.title)
                                .font(.custom("BarlowCondensed-Black", size: 12))
                                .kerning(1)
                                .foregroundColor(Color.white.opacity(0.87))
                        }
                        Text(event.detail)
                            .font(.custom("BarlowCondensed-Bold", size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(event.isKey ? Color.white.opacity(0.06) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - Player Card with Headshot

private struct PlayerSilhouette: View {
    let name: String
    let number: Int
    let cardBg: Color
    let dark: Color
    var sport: String = "soccer"

    var parts: [String] { name.split(separator: " ").map(String.init) }
    var surname: String { parts.last?.uppercased() ?? name.uppercased() }
    var first: String?  { parts.count > 1 ? parts.first?.uppercased() : nil }

    private var headshotURL: URL? {
        let playerIDs: [String: String] = [
            "onana": "nfl/players/full/4567048.png",
            "rashford": "soccer/players/full/221665.png",
            "fernandes": "soccer/players/full/227531.png",
            "hojlund": "soccer/players/full/282023.png",
            "palmer": "soccer/players/full/282173.png",
            "jackson": "soccer/players/full/265498.png",
            "caicedo": "soccer/players/full/282119.png",
            "lebron": "nba/players/full/1966.png",
            "davis": "nba/players/full/6583.png",
            "reaves": "nba/players/full/4397018.png",
            "tatum": "nba/players/full/4065648.png",
            "brown": "nba/players/full/3917376.png",
            "curry": "nba/players/full/3975.png",
            "jokic": "nba/players/full/3112335.png",
            "murray": "nba/players/full/3936299.png",
            "mahomes": "nfl/players/full/3139477.png",
            "kelce": "nfl/players/full/15847.png",
            "purdy": "nfl/players/full/4432577.png",
            "mccaffrey": "nfl/players/full/3117251.png",
            "mackinnon": "nhl/players/full/3041969.png",
            "mcdavid": "nhl/players/full/3895074.png",
            "draisaitl": "nhl/players/full/3114727.png",
            "verstappen": "rpm/players/full/4665.png",
            "leclerc": "rpm/players/full/5765.png",
            "rohit": "cricket/players/full/28081.png",
            "bumrah": "cricket/players/full/625383.png",
            "dhoni": "cricket/players/full/28081.png",
        ]

        let lastNameLower = (parts.last ?? name).lowercased()
            .replacingOccurrences(of: "í", with: "i")
            .replacingOccurrences(of: "á", with: "a")
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "č", with: "c")
            .replacingOccurrences(of: "ž", with: "z")
            .replacingOccurrences(of: "ñ", with: "n")

        if let path = playerIDs[lastNameLower] {
            return URL(string: "https://a.espncdn.com/i/headshots/\(path)")
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08))

            if let url = headshotURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(width: 90, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.7), Color.clear, Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            )
                    default:
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color.white.opacity(0.1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(y: 4)
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color.white.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: 4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Spacer()
                if let f = first {
                    Text(f)
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(surname)
                    .font(.custom("BarlowCondensed-Black", size: 16))
                    .foregroundColor(.white)
                Text("\(number)")
                    .font(.custom("BarlowCondensed-Black", size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(8)
        }
        .frame(width: 90, height: 128)
        .clipped()
    }
}

// MARK: - Shared subviews

private struct SectionLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.custom("BarlowCondensed-Bold", size: 9))
            .kerning(2.2).textCase(.uppercase)
            .foregroundColor(color)
            .padding(.bottom, 10)
    }
}

// MARK: - Preview

#Preview {
    Pick6MainView()
}
