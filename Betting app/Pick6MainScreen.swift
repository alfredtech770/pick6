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

// MARK: - Header (floating pill with 3D sport carousel)

private struct Pick6Header: View {
    @Binding var showFavorites: Bool
    @Binding var showProfile: Bool
    let activeSport: Sport
    let sports: [Sport]
    @Binding var currentIndex: Int

    // Drag state for the sport carousel
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false

    private let logoSize: CGFloat = 68
    private let sideLogoSize: CGFloat = 44
    private let carouselWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 12) {
            // ── Profile avatar (left) ──
            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#8E8E93"), Color(hex: "#48484A")],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.90))
                        .offset(y: 1)
                }
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // ── Sports pill (center) ──
            ZStack {
                ForEach(Array(sports.enumerated()), id: \.element.id) { index, sport in
                    let offset = CGFloat(index - currentIndex)
                    let totalOffset = offset * 70 + dragOffset

                    SportLogoItem(sport: sport, size: logoSize, sideSize: sideLogoSize)
                        .scaleEffect(scaleFor(totalOffset))
                        .opacity(opacityFor(totalOffset))
                        .offset(x: xPositionFor(totalOffset))
                        .offset(y: yPositionFor(totalOffset))
                        .rotation3DEffect(
                            .degrees(rotationFor(totalOffset)),
                            axis: (0, 1, 0),
                            perspective: 0.4
                        )
                        .zIndex(zIndexFor(totalOffset))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentIndex)
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                }
            }
            .frame(width: carouselWidth, height: 72)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        dragOffset = value.translation.width * 0.5
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 30
                        let velocity = value.predictedEndTranslation.width - value.translation.width

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            if (value.translation.width + velocity * 0.3) < -threshold && currentIndex < sports.count - 1 {
                                currentIndex += 1
                            } else if (value.translation.width + velocity * 0.3) > threshold && currentIndex > 0 {
                                currentIndex -= 1
                            }
                            dragOffset = 0
                        }
                    }
            )

            Spacer(minLength: 0)

            // ── Favorites button (right) ──
            Button { showFavorites = true } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#2A2A2E"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "star.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // 3D carousel math — maps an offset to position, scale, rotation, etc.
    private func scaleFor(_ offset: CGFloat) -> CGFloat {
        let normalized = abs(offset) / 70.0
        return max(0.45, 1.0 - normalized * 0.40)
    }

    private func opacityFor(_ offset: CGFloat) -> Double {
        let normalized = abs(offset) / 70.0
        if normalized > 2.0 { return 0 }
        return max(0.0, 1.0 - normalized * 0.55)
    }

    private func xPositionFor(_ offset: CGFloat) -> CGFloat {
        // Compress side items closer to center for a tight carousel feel
        let sign: CGFloat = offset >= 0 ? 1 : -1
        let normalized = abs(offset) / 70.0
        return sign * normalized * 52
    }

    private func yPositionFor(_ offset: CGFloat) -> CGFloat {
        // Side items drop down slightly for depth
        let normalized = abs(offset) / 70.0
        return normalized * 3
    }

    private func rotationFor(_ offset: CGFloat) -> Double {
        let normalized = offset / 70.0
        return Double(-normalized * 45)
    }

    private func zIndexFor(_ offset: CGFloat) -> Double {
        return Double(-abs(offset))
    }
}

// Individual sport logo item for the carousel
// MARK: - Soccer Field Visual (Apple Sports style)

// MARK: - F1 Circuit Track Visual
private struct F1CircuitView: View {
    let teamColor: Color
    let circuitName: String

    var body: some View {
        ZStack {
            // Dark asphalt background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#1A1A1C"))

            // Subtle grid lines (road texture)
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let gridColor = Color.white.opacity(0.03)
                for i in stride(from: CGFloat(0), to: w, by: 20) {
                    var p = Path()
                    p.move(to: CGPoint(x: i, y: 0))
                    p.addLine(to: CGPoint(x: i, y: h))
                    ctx.stroke(p, with: .color(gridColor), lineWidth: 0.5)
                }
                for j in stride(from: CGFloat(0), to: h, by: 20) {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: j))
                    p.addLine(to: CGPoint(x: w, y: j))
                    ctx.stroke(p, with: .color(gridColor), lineWidth: 0.5)
                }
            }

            // Track outline — Albert Park style (simplified abstract shape)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let mx: CGFloat = 40  // margin x
                let my: CGFloat = 30  // margin y

                // The track path (abstract street circuit)
                Path { p in
                    // Start/finish straight (bottom)
                    p.move(to: CGPoint(x: mx + w * 0.15, y: h - my))

                    // Bottom-right curve → right side
                    p.addCurve(
                        to: CGPoint(x: w - mx, y: h * 0.65),
                        control1: CGPoint(x: w * 0.55, y: h - my),
                        control2: CGPoint(x: w - mx, y: h * 0.85)
                    )

                    // Right side → top-right hairpin
                    p.addCurve(
                        to: CGPoint(x: w - mx - w * 0.05, y: my + h * 0.08),
                        control1: CGPoint(x: w - mx, y: h * 0.40),
                        control2: CGPoint(x: w - mx + 5, y: my + h * 0.12)
                    )

                    // Top section — flowing left
                    p.addCurve(
                        to: CGPoint(x: w * 0.45, y: my),
                        control1: CGPoint(x: w * 0.78, y: my - 5),
                        control2: CGPoint(x: w * 0.60, y: my + h * 0.05)
                    )

                    // Top-left chicane
                    p.addCurve(
                        to: CGPoint(x: mx + w * 0.05, y: my + h * 0.15),
                        control1: CGPoint(x: w * 0.30, y: my - 5),
                        control2: CGPoint(x: mx + w * 0.02, y: my + h * 0.02)
                    )

                    // Left side — down through esses
                    p.addCurve(
                        to: CGPoint(x: mx, y: h * 0.50),
                        control1: CGPoint(x: mx + w * 0.08, y: my + h * 0.28),
                        control2: CGPoint(x: mx - 8, y: h * 0.35)
                    )

                    // Bottom-left — back to start
                    p.addCurve(
                        to: CGPoint(x: mx + w * 0.15, y: h - my),
                        control1: CGPoint(x: mx + 8, y: h * 0.65),
                        control2: CGPoint(x: mx + w * 0.05, y: h - my - 5)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [teamColor.opacity(0.7), teamColor.opacity(0.3), .white.opacity(0.25)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

                // Track glow effect (wider, blurred)
                Path { p in
                    p.move(to: CGPoint(x: mx + w * 0.15, y: h - my))
                    p.addCurve(
                        to: CGPoint(x: w - mx, y: h * 0.65),
                        control1: CGPoint(x: w * 0.55, y: h - my),
                        control2: CGPoint(x: w - mx, y: h * 0.85)
                    )
                    p.addCurve(
                        to: CGPoint(x: w - mx - w * 0.05, y: my + h * 0.08),
                        control1: CGPoint(x: w - mx, y: h * 0.40),
                        control2: CGPoint(x: w - mx + 5, y: my + h * 0.12)
                    )
                    p.addCurve(
                        to: CGPoint(x: w * 0.45, y: my),
                        control1: CGPoint(x: w * 0.78, y: my - 5),
                        control2: CGPoint(x: w * 0.60, y: my + h * 0.05)
                    )
                    p.addCurve(
                        to: CGPoint(x: mx + w * 0.05, y: my + h * 0.15),
                        control1: CGPoint(x: w * 0.30, y: my - 5),
                        control2: CGPoint(x: mx + w * 0.02, y: my + h * 0.02)
                    )
                    p.addCurve(
                        to: CGPoint(x: mx, y: h * 0.50),
                        control1: CGPoint(x: mx + w * 0.08, y: my + h * 0.28),
                        control2: CGPoint(x: mx - 8, y: h * 0.35)
                    )
                    p.addCurve(
                        to: CGPoint(x: mx + w * 0.15, y: h - my),
                        control1: CGPoint(x: mx + 8, y: h * 0.65),
                        control2: CGPoint(x: mx + w * 0.05, y: h - my - 5)
                    )
                }
                .stroke(teamColor.opacity(0.15), lineWidth: 14)
                .blur(radius: 6)

                // Start/finish line marker
                let sfX = mx + w * 0.15
                let sfY = h - my
                Path { p in
                    p.move(to: CGPoint(x: sfX - 8, y: sfY))
                    p.addLine(to: CGPoint(x: sfX + 8, y: sfY))
                }
                .stroke(.white.opacity(0.8), lineWidth: 3)

                // DRS zone indicator
                Path { p in
                    p.move(to: CGPoint(x: w * 0.55, y: h - my + 8))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.78))
                }
                .stroke(Color(hex: "#22C55E").opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))

                // Sector dots
                Circle()
                    .fill(Color(hex: "#FF453A").opacity(0.7))
                    .frame(width: 6, height: 6)
                    .position(x: w - mx - w * 0.05, y: my + h * 0.08)

                Circle()
                    .fill(Color(hex: "#FFD60A").opacity(0.7))
                    .frame(width: 6, height: 6)
                    .position(x: mx + w * 0.05, y: my + h * 0.15)

                Circle()
                    .fill(Color(hex: "#30D5C8").opacity(0.7))
                    .frame(width: 6, height: 6)
                    .position(x: mx, y: h * 0.50)
            }

            // Circuit name overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(circuitName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.35))
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "#FF453A").opacity(0.6)).frame(width: 5, height: 5)
                            Text("S1").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.25))
                            Circle().fill(Color(hex: "#FFD60A").opacity(0.6)).frame(width: 5, height: 5)
                            Text("S2").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.25))
                            Circle().fill(Color(hex: "#30D5C8").opacity(0.6)).frame(width: 5, height: 5)
                            Text("S3").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

private struct SoccerFieldView: View {
    let homeColor: Color
    let awayColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let _ = geo.size.height

            ZStack {
                // Dark field base
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#0D1F0D"))

                // Subtle grass stripe pattern
                Canvas { ctx, size in
                    let stripeW = size.width / 12
                    for i in 0..<12 {
                        if i % 2 == 0 {
                            ctx.fill(
                                Path(CGRect(x: CGFloat(i) * stripeW, y: 0, width: stripeW, height: size.height)),
                                with: .color(Color.white.opacity(0.015))
                            )
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Field markings
                Canvas { ctx, size in
                    let lw: CGFloat = 1.0
                    let lineCol = Color.white.opacity(0.12)
                    let m: CGFloat = 14
                    let fw = size.width - m * 2
                    let fh = size.height - m * 2

                    // Outer boundary
                    ctx.stroke(Path(CGRect(x: m, y: m, width: fw, height: fh)), with: .color(lineCol), lineWidth: lw)

                    // Center line
                    var cl = Path()
                    cl.move(to: CGPoint(x: size.width / 2, y: m))
                    cl.addLine(to: CGPoint(x: size.width / 2, y: size.height - m))
                    ctx.stroke(cl, with: .color(lineCol), lineWidth: lw)

                    // Center circle
                    let cr = fh * 0.24
                    let cx = size.width / 2
                    let cy = size.height / 2
                    ctx.stroke(Path(ellipseIn: CGRect(x: cx - cr, y: cy - cr, width: cr * 2, height: cr * 2)), with: .color(lineCol), lineWidth: lw)

                    // Center dot
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)), with: .color(lineCol))

                    // Penalty boxes
                    let pbW = fw * 0.15
                    let pbH = fh * 0.58
                    let pbY = m + (fh - pbH) / 2
                    ctx.stroke(Path(CGRect(x: m, y: pbY, width: pbW, height: pbH)), with: .color(lineCol), lineWidth: lw)
                    ctx.stroke(Path(CGRect(x: size.width - m - pbW, y: pbY, width: pbW, height: pbH)), with: .color(lineCol), lineWidth: lw)

                    // 6-yard boxes
                    let sbW = pbW * 0.42
                    let sbH = pbH * 0.48
                    let sbY = m + (fh - sbH) / 2
                    ctx.stroke(Path(CGRect(x: m, y: sbY, width: sbW, height: sbH)), with: .color(lineCol), lineWidth: lw)
                    ctx.stroke(Path(CGRect(x: size.width - m - sbW, y: sbY, width: sbW, height: sbH)), with: .color(lineCol), lineWidth: lw)

                    // Penalty arcs
                    let ar = cr * 0.6
                    var la = Path()
                    la.addArc(center: CGPoint(x: m + pbW, y: cy), radius: ar, startAngle: .degrees(-38), endAngle: .degrees(38), clockwise: false)
                    ctx.stroke(la, with: .color(lineCol), lineWidth: lw)
                    var ra = Path()
                    ra.addArc(center: CGPoint(x: size.width - m - pbW, y: cy), radius: ar, startAngle: .degrees(142), endAngle: .degrees(218), clockwise: false)
                    ctx.stroke(ra, with: .color(lineCol), lineWidth: lw)

                    // Penalty dots
                    let pdx = m + pbW * 0.72
                    ctx.fill(Path(ellipseIn: CGRect(x: pdx - 1.5, y: cy - 1.5, width: 3, height: 3)), with: .color(lineCol))
                    ctx.fill(Path(ellipseIn: CGRect(x: size.width - pdx - 1.5, y: cy - 1.5, width: 3, height: 3)), with: .color(lineCol))

                    // Corner arcs
                    let cAr: CGFloat = 7
                    for (pt, s, e) in [
                        (CGPoint(x: m, y: m), 0.0, 90.0),
                        (CGPoint(x: size.width - m, y: m), 90.0, 180.0),
                        (CGPoint(x: size.width - m, y: size.height - m), 180.0, 270.0),
                        (CGPoint(x: m, y: size.height - m), 270.0, 360.0)
                    ] {
                        var c = Path()
                        c.addArc(center: pt, radius: cAr, startAngle: .degrees(s), endAngle: .degrees(e), clockwise: false)
                        ctx.stroke(c, with: .color(lineCol), lineWidth: lw)
                    }
                }

                // Team color ambient glow — very subtle
                HStack(spacing: 0) {
                    RadialGradient(
                        colors: [homeColor.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: w * 0.45
                    )
                    RadialGradient(
                        colors: [awayColor.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: w * 0.45
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}

private struct SportLogoItem: View {
    let sport: Sport
    let size: CGFloat
    let sideSize: CGFloat

    var body: some View {
        if !sport.logoURL.isEmpty, let url = URL(string: sport.logoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: size, height: size)
                default:
                    Image(systemName: sport.sfSymbol)
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        } else {
            Image(systemName: sport.sfSymbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Main List

private struct MainListView: View {
    @Binding var activeSport: Sport
    @Binding var showFavorites: Bool
    @Binding var showProfile: Bool
    let onSelectMatch: (MatchData) -> Void

    @State private var currentIndex: Int = 0
    @State private var selectedTimeline: String = "today"
    private let sports = Pick6Data.allSports

    var body: some View {
        VStack(spacing: 0) {
            Pick6Header(
                showFavorites: $showFavorites,
                showProfile: $showProfile,
                activeSport: activeSport,
                sports: sports,
                currentIndex: $currentIndex
            )

            // ── Timeline picker (Apple Sports style) ──
            TimelinePicker(selected: $selectedTimeline)
                .padding(.top, 6)
                .padding(.bottom, 2)

            // Horizontal sport pager (TabView handles horizontal gestures)
            TabView(selection: $currentIndex) {
                ForEach(Array(sports.enumerated()), id: \.element.id) { index, sport in
                    SportPageContent(sport: sport, timeline: selectedTimeline, onSelectMatch: onSelectMatch)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)
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
    let timeline: String
    let onSelectMatch: (MatchData) -> Void

    var league: LeagueData { Pick6Data.leagues[sport.id]! }
    var filteredMatches: [MatchData] {
        league.matches.filter { $0.timeline == timeline }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Title — overlaps into scroll area for seamless look ──
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
            .padding(.top, 18)
            .padding(.bottom, 10)

            // ── Vertical card carousel — native ScrollView with snap ──
            if filteredMatches.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No games \(timeline == "yesterday" ? "yesterday" : timeline == "upcoming" ? "scheduled" : "today")")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredMatches) { match in
                            Button {
                                onSelectMatch(match)
                            } label: {
                                MatchCard(match: match, visible: true, isF1: sport.id == "f1", isTennis: sport.id == "tennis")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .containerRelativeFrame(.vertical) { length, _ in
                                sport.id == "f1" ? length * 0.32 : length * 0.80
                            }
                            .scrollTransition(.animated(.spring(response: 0.35, dampingFraction: 0.88))) { content, phase in
                                let gone = phase.value < 0   // card scrolling away (upward)
                                let v = abs(phase.value)
                                return content
                                    .scaleEffect(
                                        x: phase.isIdentity ? 1.0 : (gone ? 1.0 - v * 0.10 : 1.0 - v * 0.04),
                                        y: phase.isIdentity ? 1.0 : (gone ? 1.0 - v * 0.10 : 1.0 - v * 0.04)
                                    )
                                    .opacity(phase.isIdentity ? 1.0 : (gone ? max(0, 1.0 - v * 1.8) : 1.0 - v * 0.25))
                                    .offset(y: phase.isIdentity ? 0 : (gone ? phase.value * 60 : 0))
                                    .blur(radius: phase.isIdentity ? 0 : (gone ? v * 6 : v * 0.5))
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .safeAreaPadding(.top, 4)
                    .safeAreaPadding(.bottom, 6)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollContentBackground(.hidden)
                .scrollClipDisabled(true)
            }
        }
    }
}

// MARK: - Timeline Picker (Apple Sports style)

private struct TimelinePicker: View {
    @Binding var selected: String

    private let options = [
        ("yesterday", "Yesterday"),
        ("today", "Today"),
        ("upcoming", "Upcoming")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { key, label in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selected = key
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: selected == key ? .bold : .medium))
                        .foregroundColor(selected == key ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selected == key {
                                    Capsule()
                                        .fill(Color.white.opacity(0.10))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(hex: "#1C1C1E"))
        )
        .padding(.horizontal, 16)
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
    var isTennis: Bool = false

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

            if isF1 {
                // F1: team color gradient from left
                LinearGradient(
                    colors: [match.home.hex.opacity(0.40), match.home.hex.opacity(0.15), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                // Secondary warm glow at top
                LinearGradient(
                    colors: [match.home.hex.opacity(0.25), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                // ── Track outline overlay ──
                HStack {
                    Spacer()
                    f1TrackImage(for: match.f1CircuitName)
                        .opacity(0.06)
                        .frame(width: 120, height: 100)
                        .offset(x: -8, y: 4)
                }
            } else if isTennis {
                // Tennis: subtle center glow
                RadialGradient(
                    colors: [match.home.hex.opacity(0.15), Color.clear],
                    center: UnitPoint(x: 0.25, y: 0.3),
                    startRadius: 10,
                    endRadius: 200
                )
                RadialGradient(
                    colors: [match.away.hex.opacity(0.15), Color.clear],
                    center: UnitPoint(x: 0.75, y: 0.3),
                    startRadius: 10,
                    endRadius: 200
                )
            } else {
                // Home team color gradient
                LinearGradient(
                    colors: [match.home.hex.opacity(0.22), match.home.hex.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.38, y: 0.28)
                )
                // Away team color gradient
                LinearGradient(
                    colors: [match.away.hex.opacity(0.22), match.away.hex.opacity(0)],
                    startPoint: .topTrailing,
                    endPoint: UnitPoint(x: 0.62, y: 0.28)
                )
            }

            VStack(spacing: 0) {
                // ── Teams row ──
                if isF1 {
                    // ═══ Compact F1 Driver Card ═══
                    HStack(spacing: 0) {
                        // Left: driver info
                        VStack(alignment: .leading, spacing: 0) {
                            // Race info
                            HStack(spacing: 5) {
                                Text(match.f1RaceFlag)
                                    .font(.system(size: 10))
                                Text("RD \(match.f1RaceRound) · \(match.f1RaceName.uppercased())")
                                    .font(.system(size: 7, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            .padding(.bottom, 6)

                            // Team name
                            Text(match.f1TeamName.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(match.home.hex)
                                .padding(.bottom, 4)

                            // Driver name + position inline
                            HStack(alignment: .lastTextBaseline, spacing: 10) {
                                Text("P\(match.f1Position)")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundColor(.white)
                                Text(match.home.sub.uppercased())
                                    .font(.system(size: 18, weight: .black))
                                    .tracking(-0.3)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .padding(.leading, 18)
                        .padding(.vertical, 12)

                        Spacer(minLength: 8)

                        // Right: driver headshot
                        if !match.home.logoURL.isEmpty, let url = URL(string: match.home.logoURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 95, height: 105)
                                        .clipped()
                                        .mask(
                                            LinearGradient(
                                                colors: [.black, .black, .black.opacity(0)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                default:
                                    Color.clear.frame(width: 95, height: 105)
                                }
                            }
                            .padding(.trailing, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else if isTennis {
                    // ═══ Tennis Player Card — headshots face-to-face ═══
                    HStack(alignment: .top, spacing: 0) {
                        // Home player
                        VStack(spacing: 6) {
                            if !match.home.logoURL.isEmpty, let url = URL(string: match.home.logoURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                            .frame(width: 80, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(match.home.hex.opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: match.home.hex.opacity(0.25), radius: 10, x: -2, y: 4)
                                    default:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(width: 80, height: 90)
                                    }
                                }
                            }
                            VStack(spacing: 1) {
                                Text(match.home.name.uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.40))
                                Text(match.home.sub.uppercased())
                                    .font(.system(size: 16, weight: .black))
                                    .tracking(-0.3)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Center: score or time
                        VStack(spacing: 4) {
                            Spacer().frame(height: 16)
                            if match.isLive {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#FF3B30")).frame(width: 6, height: 6)
                                        .opacity(livePulse ? 0.25 : 1)
                                    Text("LIVE")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(Color(hex: "#FF3B30"))
                                }
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { livePulse = true }
                                }
                                Text("\(match.liveHomeScore) – \(match.liveAwayScore)")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(.white)
                                Text("SETS")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(.white.opacity(0.25))
                            } else {
                                Text("\(match.date) \(match.month.prefix(3).uppercased())")
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.36))
                                Text("\(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundColor(.white)
                                Text("VS")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                        .frame(width: 80)

                        // Away player
                        VStack(spacing: 6) {
                            if !match.away.logoURL.isEmpty, let url = URL(string: match.away.logoURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                            .frame(width: 80, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(match.away.hex.opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: match.away.hex.opacity(0.25), radius: 10, x: 2, y: 4)
                                    default:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(width: 80, height: 90)
                                    }
                                }
                            }
                            VStack(spacing: 1) {
                                Text(match.away.name.uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.40))
                                Text(match.away.sub.uppercased())
                                    .font(.system(size: 16, weight: .black))
                                    .tracking(-0.3)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
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

                if isF1 {
                    // ── F1 compact bottom bar ──
                    Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 16)
                    HStack(spacing: 0) {
                        // AI pick
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#22C55E"))
                            Text("P\(f1PredictedPosition(conf: match.aiConf)) PREDICTED")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        // Podium chance
                        Text("PODIUM \(match.homePct)%")
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.5)
                            .foregroundColor(match.home.hex)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                } else {
                    Spacer(minLength: 4)

                    // ── Separator ──
                    Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)

                    Spacer(minLength: 8)

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

                    Spacer(minLength: 12)

                    // ── Odds pills ──
                    HStack(spacing: 8) {
                        oddsPill(label: "WIN",  value: homeOdds, highlight: match.aiPick == "home", color: match.home.hex)
                        if match.drawPct > 0 {
                            oddsPill(label: "DRAW", value: drawOdds, highlight: match.aiPick == "draw", color: .white)
                        }
                        oddsPill(label: "LOSS", value: awayOdds, highlight: match.aiPick == "away", color: match.away.hex)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 12)

                    // ── Separator ──
                    Rectangle().fill(.white.opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)

                    Spacer(minLength: 4)

                    // ── Potential win ──
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#22C55E"))
                            Text("IF \(pickedTeamName.uppercased()) WINS")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.3)
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("$10").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.32))
                            Text("→").font(.system(size: 10)).foregroundColor(.white.opacity(0.22))
                            Text(potentialWin).font(.system(size: 22, weight: .black)).foregroundColor(Color(hex: "#22C55E"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isF1 ? 18 : 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: isF1 ? 18 : 26, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
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

    // ── F1 Track outline (SwiftUI Shape) ──
    @ViewBuilder
    private func f1TrackImage(for circuit: String) -> some View {
        // Map circuit names to track outline URLs from formula1.com
        let trackKey: String = {
            let lower = circuit.lowercased()
            if lower.contains("albert park") || lower.contains("melbourne") { return "australia" }
            if lower.contains("bahrain") || lower.contains("sakhir") { return "bahrain" }
            if lower.contains("jeddah") || lower.contains("saudi") { return "saudi-arabia" }
            if lower.contains("suzuka") || lower.contains("japan") { return "japan" }
            if lower.contains("shanghai") || lower.contains("china") { return "china" }
            if lower.contains("miami") { return "miami" }
            if lower.contains("imola") || lower.contains("emilia") { return "emilia-romagna" }
            if lower.contains("monaco") { return "monaco" }
            if lower.contains("montréal") || lower.contains("montreal") || lower.contains("canada") { return "canada" }
            if lower.contains("barcelona") || lower.contains("spain") { return "spain" }
            if lower.contains("silverstone") || lower.contains("britain") { return "great-britain" }
            if lower.contains("hungaroring") || lower.contains("hungary") { return "hungary" }
            if lower.contains("spa") || lower.contains("belgium") { return "belgium" }
            if lower.contains("zandvoort") || lower.contains("netherlands") { return "netherlands" }
            if lower.contains("monza") || lower.contains("italy") { return "italy" }
            if lower.contains("singapore") || lower.contains("marina bay") { return "singapore" }
            if lower.contains("austin") || lower.contains("cota") || lower.contains("united states") { return "united-states" }
            if lower.contains("interlagos") || lower.contains("brazil") || lower.contains("são paulo") { return "brazil" }
            if lower.contains("las vegas") { return "las-vegas" }
            if lower.contains("lusail") || lower.contains("qatar") { return "qatar" }
            if lower.contains("yas marina") || lower.contains("abu dhabi") { return "abu-dhabi" }
            return "australia"
        }()
        let url = URL(string: "https://media.formula1.com/image/upload/f_auto/q_auto/v1677245035/content/dam/fom-website/2018-redesign-assets/Track%20Outline%20with%20the%20line/\(trackKey).png")
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .colorMultiply(.white)
                default:
                    Color.clear
                }
            }
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

// MARK: - Match Detail Page (Apple Sports style)

private struct MatchDetailPage: View {
    let match: MatchData
    let sport: Sport
    let totalMatches: Int
    let currentIndex: Int

    @State private var statsIn = false
    @State private var showBookmakers = false
    @State private var confValue = 0
    @State private var homeValue = 0
    @State private var awayValue = 0
    @State private var drawValue = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var barFill: CGFloat = 0

    private let bg = Color(hex: "#111113")
    private let cardBg = Color(hex: "#1C1C1E")
    private let white90 = Color.white.opacity(0.90)
    private let white60 = Color.white.opacity(0.60)
    private let white40 = Color.white.opacity(0.40)
    private let white20 = Color.white.opacity(0.20)
    private let white08 = Color.white.opacity(0.08)
    private let green = Color(hex: "#34C759")

    private var isF1: Bool { sport.id == "f1" }

    var winnerName: String {
        switch match.aiPick {
        case "home": return match.home.sub
        case "away": return match.away.sub
        default: return "Draw"
        }
    }

    private var kickoffTime: String {
        "\(match.kickoffHour):\(match.kickoffMin.count == 1 ? "0" + match.kickoffMin : match.kickoffMin)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    if isF1 {
                        f1DetailContent
                    } else {

                    // ════════════════════════════════════════════════
                    // MARK: Header — scores first, logos below (Apple Sports)
                    // ════════════════════════════════════════════════
                    ZStack(alignment: .top) {
                        // Full-bleed team color gradient
                        ZStack {
                            // Left team color
                            LinearGradient(
                                colors: [match.home.hex.opacity(0.50), match.home.hex.opacity(0.0)],
                                startPoint: .topLeading,
                                endPoint: .trailing
                            )
                            // Right team color
                            LinearGradient(
                                colors: [match.away.hex.opacity(0.50), match.away.hex.opacity(0.0)],
                                startPoint: .topTrailing,
                                endPoint: .leading
                            )
                            // Fade to bg at bottom
                            LinearGradient(
                                colors: [Color.clear, Color.clear, bg.opacity(0.6), bg],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }

                        VStack(spacing: 0) {
                            // League name
                            Text(sport.label.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(white60)
                                .padding(.top, 16)

                            // ── Apple Sports style: logo + score on same line ──
                            if match.isLive {
                                // Live: Home logo — score — center status — score — Away logo
                                HStack(alignment: .center, spacing: 0) {
                                    // Home side
                                    VStack(spacing: 6) {
                                        HStack(spacing: 14) {
                                            Pick6TeamLogo(team: match.home, size: 52)
                                                .shadow(color: match.home.hex.opacity(0.35), radius: 10, y: 4)
                                            Text("\(match.liveHomeScore)")
                                                .font(.system(size: 64, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        Text(match.home.sub.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(white90)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Center: live indicator
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color(hex: "#34C759")).frame(width: 6, height: 6)
                                                .opacity(pulseOpacity)
                                            Text("\(match.liveMinute)'")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Color(hex: "#34C759"))
                                        }
                                    }
                                    .frame(width: 56)

                                    // Away side
                                    VStack(spacing: 6) {
                                        HStack(spacing: 14) {
                                            Text("\(match.liveAwayScore)")
                                                .font(.system(size: 64, weight: .bold))
                                                .foregroundColor(.white)
                                            Pick6TeamLogo(team: match.away, size: 52)
                                                .shadow(color: match.away.hex.opacity(0.35), radius: 10, y: 4)
                                        }
                                        Text(match.away.sub.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(white90)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                            } else {
                                // Upcoming: Home logo — kickoff time — Away logo
                                HStack(alignment: .center, spacing: 0) {
                                    // Home side
                                    VStack(spacing: 6) {
                                        Pick6TeamLogo(team: match.home, size: 52)
                                            .shadow(color: match.home.hex.opacity(0.35), radius: 10, y: 4)
                                        Text(match.home.sub.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(white90)
                                            .lineLimit(1)
                                        Text(match.home.name.uppercased())
                                            .font(.system(size: 10, weight: .medium))
                                            .tracking(0.5)
                                            .foregroundColor(white40)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)

                                    // Center: kickoff
                                    VStack(spacing: 4) {
                                        Text(kickoffTime)
                                            .font(.system(size: 38, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Text("\(match.date) \(match.month.prefix(3).uppercased())")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(white40)
                                    }
                                    .frame(width: 120)

                                    // Away side
                                    VStack(spacing: 6) {
                                        Pick6TeamLogo(team: match.away, size: 52)
                                            .shadow(color: match.away.hex.opacity(0.35), radius: 10, y: 4)
                                        Text(match.away.sub.uppercased())
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(white90)
                                            .lineLimit(1)
                                        Text(match.away.name.uppercased())
                                            .font(.system(size: 10, weight: .medium))
                                            .tracking(0.5)
                                            .foregroundColor(white40)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                            }

                            // Live progress bar
                            if match.isLive && match.liveMinute > 0 {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(white08).frame(height: 3)
                                        Capsule()
                                            .fill(green)
                                            .frame(width: geo.size.width * CGFloat(match.liveMinute) / 90.0, height: 3)
                                    }
                                }
                                .frame(height: 3)
                                .padding(.horizontal, 40)
                                .padding(.top, 14)
                                HStack {
                                    Text("0'").font(.system(size: 9, weight: .medium)).foregroundColor(white20)
                                    Spacer()
                                    Text("45'").font(.system(size: 9, weight: .medium)).foregroundColor(white20)
                                    Spacer()
                                    Text("90'").font(.system(size: 9, weight: .medium)).foregroundColor(white20)
                                }
                                .padding(.horizontal, 38)
                                .padding(.top, 3)
                            }
                        }
                    }
                    .frame(height: match.isLive ? 280 : 220)

                    // ════════════════════════════════════════════════
                    // MARK: Soccer Field Visual (soccer only)
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" {
                    SoccerFieldView(
                        homeColor: match.home.hex,
                        awayColor: match.away.hex
                    )
                    .frame(height: 150)
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 6)
                    } // end soccer field

                    // ════════════════════════════════════════════════
                    // 1. AI PREDICTION — the core value
                    // ════════════════════════════════════════════════
                    sectionCard("AI Prediction") {
                        // Pick + confidence row
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(green.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PICK: \(winnerName.uppercased())")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundColor(.white)
                                Text("\(confValue)% confidence")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(white40)
                            }
                            Spacer()
                            Text("\(confValue)%")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(green)
                        }
                        .padding(.bottom, 12)

                        // Reasoning
                        Text(match.aiReason)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(white60)
                            .lineSpacing(5)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(white08.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // ════════════════════════════════════════════════
                    // 2. BETTING ODDS — actionable
                    // ════════════════════════════════════════════════
                    sectionCard("Betting Odds") {
                        // Table header
                        HStack(spacing: 0) {
                            Text("Team").font(.system(size: 11, weight: .semibold)).foregroundColor(white40)
                                .frame(width: 80, alignment: .leading)
                            Text("Win %").font(.system(size: 11, weight: .semibold)).foregroundColor(white40)
                                .frame(maxWidth: .infinity)
                            Text("Odds").font(.system(size: 11, weight: .semibold)).foregroundColor(white40)
                                .frame(maxWidth: .infinity)
                            Text("AI Pick").font(.system(size: 11, weight: .semibold)).foregroundColor(white40)
                                .frame(width: 50)
                        }
                        .padding(.bottom, 6)
                        Rectangle().fill(white08).frame(height: 0.5)

                        oddsTableRow(
                            abbr: match.home.abbr,
                            pct: "\(match.homePct)%",
                            odds: match.homePct > 0 ? String(format: "%.2f", 100.0 / Double(match.homePct)) : "–",
                            picked: match.aiPick == "home"
                        )
                        Rectangle().fill(white08).frame(height: 0.5)

                        if match.drawPct > 0 {
                            oddsTableRow(
                                abbr: "DRAW",
                                pct: "\(match.drawPct)%",
                                odds: String(format: "%.2f", 100.0 / Double(match.drawPct)),
                                picked: match.aiPick == "draw"
                            )
                            Rectangle().fill(white08).frame(height: 0.5)
                        }

                        oddsTableRow(
                            abbr: match.away.abbr,
                            pct: "\(match.awayPct)%",
                            odds: match.awayPct > 0 ? String(format: "%.2f", 100.0 / Double(match.awayPct)) : "–",
                            picked: match.aiPick == "away"
                        )
                    }

                    // ════════════════════════════════════════════════
                    // 3. LIVE MATCH STATS — soccer live only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" && match.isLive {
                        sectionCard("Match Stats") {
                            VStack(spacing: 2) {
                                teamStatBar(label: "Possession", homeVal: match.livePossHome, awayVal: match.livePossAway, homeLabel: "\(match.livePossHome)%", awayLabel: "\(match.livePossAway)%")
                                teamStatBar(label: "Shots", homeVal: match.liveShotsHome, awayVal: max(1, match.liveShotsAway), homeLabel: "\(match.liveShotsHome)", awayLabel: "\(match.liveShotsAway)")
                                teamStatBar(label: "Shots on Target", homeVal: match.liveShotsOnHome, awayVal: max(1, match.liveShotsOnAway), homeLabel: "\(match.liveShotsOnHome)", awayLabel: "\(match.liveShotsOnAway)")
                                teamStatBar(label: "Corners", homeVal: match.liveCornersHome, awayVal: max(1, match.liveCornersAway), homeLabel: "\(match.liveCornersHome)", awayLabel: "\(match.liveCornersAway)")
                                teamStatBar(label: "Fouls", homeVal: match.liveFoulsHome, awayVal: max(1, match.liveFoulsAway), homeLabel: "\(match.liveFoulsHome)", awayLabel: "\(match.liveFoulsAway)")
                                teamStatBar(label: "Yellow Cards", homeVal: match.liveYellowHome, awayVal: max(1, match.liveYellowAway), homeLabel: "\(match.liveYellowHome)", awayLabel: "\(match.liveYellowAway)")
                                if match.liveRedHome > 0 || match.liveRedAway > 0 {
                                    teamStatBar(label: "Red Cards", homeVal: match.liveRedHome, awayVal: max(1, match.liveRedAway), homeLabel: "\(match.liveRedHome)", awayLabel: "\(match.liveRedAway)")
                                }
                            }
                        }

                        // Goal scorers
                        if !match.goalScorers.isEmpty {
                            sectionCard("Goal Scorers") {
                                ForEach(Array(match.goalScorers.enumerated()), id: \.offset) { idx, goal in
                                    HStack(spacing: 12) {
                                        if goal.isHome {
                                            Text(goal.player)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(white90)
                                            Text("\(goal.minute)'")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(white40)
                                            Spacer()
                                            Image(systemName: "soccerball")
                                                .font(.system(size: 13))
                                                .foregroundColor(match.home.hex)
                                        } else {
                                            Image(systemName: "soccerball")
                                                .font(.system(size: 13))
                                                .foregroundColor(match.away.hex)
                                            Spacer()
                                            Text("\(goal.minute)'")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(white40)
                                            Text(goal.player)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(white90)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    if idx < match.goalScorers.count - 1 {
                                        Rectangle().fill(white08).frame(height: 0.5)
                                    }
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════
                    // 4. TEAM STATS — visual comparison bars
                    // ════════════════════════════════════════════════
                    sectionCard("Team Stats") {
                        VStack(spacing: 2) {
                            teamStatBar(
                                label: "Win Rate",
                                homeVal: match.homePct,
                                awayVal: match.awayPct,
                                homeLabel: "\(match.homePct)%",
                                awayLabel: "\(match.awayPct)%"
                            )
                            teamStatBar(
                                label: "Goals/Game",
                                homeVal: Int(match.home.goalsPerGame * 20),
                                awayVal: Int(match.away.goalsPerGame * 20),
                                homeLabel: String(format: "%.1f", match.home.goalsPerGame),
                                awayLabel: String(format: "%.1f", match.away.goalsPerGame)
                            )
                            teamStatBar(
                                label: "Form (Last 5)",
                                homeVal: match.home.form.filter { $0 == .win || $0 == .podium }.count * 20,
                                awayVal: match.away.form.filter { $0 == .win || $0 == .podium }.count * 20,
                                homeLabel: "\(match.home.form.filter { $0 == .win || $0 == .podium }.count)W",
                                awayLabel: "\(match.away.form.filter { $0 == .win || $0 == .podium }.count)W"
                            )
                        }
                    }

                    // ════════════════════════════════════════════════
                    // 5. LEAGUE STANDINGS — soccer only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" && match.home.leaguePos > 0 && match.away.leaguePos > 0 {
                        sectionCard("League Table") {
                            // Mini standings comparison
                            VStack(spacing: 0) {
                                // Header
                                HStack(spacing: 0) {
                                    Text("#").font(.system(size: 10, weight: .bold)).foregroundColor(white40).frame(width: 24, alignment: .leading)
                                    Text("Team").font(.system(size: 10, weight: .bold)).foregroundColor(white40).frame(maxWidth: .infinity, alignment: .leading)
                                    Text("P").font(.system(size: 10, weight: .bold)).foregroundColor(white40).frame(width: 28)
                                    Text("GD").font(.system(size: 10, weight: .bold)).foregroundColor(white40).frame(width: 36)
                                    Text("Pts").font(.system(size: 10, weight: .bold)).foregroundColor(white40).frame(width: 32)
                                }
                                .padding(.bottom, 8)
                                Rectangle().fill(white08).frame(height: 0.5)

                                // Sort teams by position
                                let teams = [(match.home, true), (match.away, false)].sorted { $0.0.leaguePos < $1.0.leaguePos }
                                ForEach(Array(teams.enumerated()), id: \.offset) { _, teamPair in
                                    let team = teamPair.0
                                    HStack(spacing: 0) {
                                        Text("\(team.leaguePos)")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.white)
                                            .frame(width: 24, alignment: .leading)
                                        HStack(spacing: 8) {
                                            Pick6TeamLogo(team: team, size: 20)
                                            Text(team.sub.uppercased())
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(white90)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(team.played)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(white60)
                                            .frame(width: 28)
                                        Text(team.goalDiff)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(team.goalDiff.hasPrefix("+") ? green : Color(hex: "#FF453A"))
                                            .frame(width: 36)
                                        Text("\(team.points)")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.white)
                                            .frame(width: 32)
                                    }
                                    .padding(.vertical, 12)
                                    Rectangle().fill(white08).frame(height: 0.5)
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════
                    // 6. INJURIES & SUSPENSIONS — soccer only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" && (!match.home.injuries.isEmpty || !match.away.injuries.isEmpty) {
                        sectionCard("Injuries & Suspensions") {
                            VStack(spacing: 14) {
                                ForEach([(match.home, true), (match.away, false)], id: \.0.abbr) { team, isHome in
                                    if !team.injuries.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Pick6TeamLogo(team: team, size: 18)
                                                Text(team.sub.uppercased())
                                                    .font(.system(size: 12, weight: .bold))
                                                    .tracking(0.5)
                                                    .foregroundColor(white60)
                                            }
                                            ForEach(team.injuries, id: \.self) { injury in
                                                HStack(spacing: 8) {
                                                    Image(systemName: "cross.circle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color(hex: "#FF453A"))
                                                    Text(injury)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(white90)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════
                    // 7. KEY PLAYERS — soccer only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" && (!match.home.topScorer.isEmpty || !match.away.topScorer.isEmpty) {
                        sectionCard("Key Players") {
                            HStack(spacing: 0) {
                                // Home top scorer
                                VStack(spacing: 8) {
                                    Pick6TeamLogo(team: match.home, size: 24)
                                    Text(match.home.topScorer.uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(white90)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Image(systemName: "soccerball")
                                            .font(.system(size: 10))
                                            .foregroundColor(white40)
                                        Text("\(match.home.topScorerGoals) goals")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(white40)
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                // Divider
                                Rectangle().fill(white08).frame(width: 0.5, height: 60)

                                // Away top scorer
                                VStack(spacing: 8) {
                                    Pick6TeamLogo(team: match.away, size: 24)
                                    Text(match.away.topScorer.uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(white90)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Image(systemName: "soccerball")
                                            .font(.system(size: 10))
                                            .foregroundColor(white40)
                                        Text("\(match.away.topScorerGoals) goals")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(white40)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // ════════════════════════════════════════════════
                    // 8. FORM GUIDE — recent momentum
                    // ════════════════════════════════════════════════
                    sectionCard("Form Guide") {
                        DetailFormRow(team: match.home, statsIn: statsIn)
                        Rectangle().fill(white08).frame(height: 0.5).padding(.vertical, 10)
                        DetailFormRow(team: match.away, statsIn: statsIn)
                    }

                    // ════════════════════════════════════════════════
                    // 5. HEAD TO HEAD — historical context
                    // ════════════════════════════════════════════════
                    sectionCard("Head to Head") {
                        ForEach(match.h2h, id: \.date) { g in
                            HStack {
                                Text(g.date)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(white40)
                                    .frame(width: 58, alignment: .leading)
                                Spacer()
                                HStack(spacing: 10) {
                                    Pick6TeamLogo(team: match.home, size: 22)
                                    Text(g.score)
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(white90)
                                    Pick6TeamLogo(team: match.away, size: 22)
                                }
                                Spacer()
                                Text(g.outcome == "home" ? match.home.abbr : g.outcome == "away" ? match.away.abbr : "DRAW")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundColor(g.outcome == "draw" ? white40 : white90)
                                    .frame(width: 46, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .overlay(Rectangle().fill(white08).frame(height: 0.5), alignment: .bottom)
                        }

                        // Record summary
                        let homeWins = match.h2h.filter { $0.outcome == "home" }.count
                        let draws    = match.h2h.filter { $0.outcome == "draw" }.count
                        let awayWins = match.h2h.filter { $0.outcome == "away" }.count
                        HStack(spacing: 0) {
                            VStack(spacing: 3) {
                                Text("\(homeWins)").font(.system(size: 26, weight: .black)).foregroundColor(.white)
                                Text(match.home.abbr).font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundColor(white40)
                            }.frame(maxWidth: .infinity)
                            VStack(spacing: 3) {
                                Text("\(draws)").font(.system(size: 26, weight: .black)).foregroundColor(.white)
                                Text("DRAW").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundColor(white40)
                            }.frame(maxWidth: .infinity)
                            VStack(spacing: 3) {
                                Text("\(awayWins)").font(.system(size: 26, weight: .black)).foregroundColor(.white)
                                Text(match.away.abbr).font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundColor(white40)
                            }.frame(maxWidth: .infinity)
                        }
                        .padding(12)
                        .background(white08.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 10)
                    }

                    // ════════════════════════════════════════════════
                    // 6. LINEUPS — soccer only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" {
                    ForEach([(match.home, match.homeLineup), (match.away, match.awayLineup)], id: \.0.abbr) { team, lineup in
                        sectionCard("\(team.name) \(team.sub) — Lineup") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(lineup.enumerated()), id: \.offset) { idx, playerName in
                                        PlayerSilhouette(name: playerName, number: idx + 1, cardBg: cardBg, dark: white90)
                                    }
                                }
                            }
                        }
                    }
                    } // end soccer lineups

                    // ════════════════════════════════════════════════
                    // MATCH INFO — venue, referee, broadcast
                    // ════════════════════════════════════════════════
                    if !match.venue.isEmpty {
                        sectionCard("Match Info") {
                            VStack(spacing: 0) {
                                if !match.venue.isEmpty {
                                    matchInfoRow(icon: "mappin.circle.fill", label: "Venue", value: match.venue)
                                    Rectangle().fill(white08).frame(height: 0.5)
                                }
                                if !match.referee.isEmpty {
                                    matchInfoRow(icon: "person.badge.shield.checkmark.fill", label: "Referee", value: match.referee)
                                    Rectangle().fill(white08).frame(height: 0.5)
                                }
                                if !match.broadcast.isEmpty {
                                    matchInfoRow(icon: "tv.fill", label: "Watch", value: match.broadcast)
                                }
                            }
                        }
                    }

                    // ════════════════════════════════════════════════
                    // MATCH TIMELINE — soccer live only
                    // ════════════════════════════════════════════════
                    if sport.id == "soccer" && match.isLive {
                        sectionCard("Match Timeline") {
                            LiveTimelineDark(match: match)
                        }
                    }

                    } // end else (non-F1)

                    Spacer().frame(height: 110)
                }
            }

            // ════════════════════════════════════════════════
            // MARK: Sticky BET NOW
            // ════════════════════════════════════════════════
            VStack(spacing: 0) {
                if showBookmakers {
                    VStack(spacing: 0) {
                        ForEach(Array(["Betclic","Winamax","Unibet","PMU","Bwin"].enumerated()), id: \.offset) { i, name in
                            HStack {
                                Text(name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(white40)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            if i < 4 { Rectangle().fill(white08).frame(height: 0.5) }
                        }
                    }
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(white08, lineWidth: 0.5))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 10)
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showBookmakers.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: showBookmakers ? "xmark" : "dollarsign.circle.fill")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        Text(showBookmakers ? "CLOSE" : "BET NOW")
                            .font(.system(size: 16, weight: .black))
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color(hex: "#22C55E"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(
                LinearGradient(colors: [Color.clear, bg, bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                    .ignoresSafeArea(.all, edges: .bottom),
                alignment: .bottom
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { statsIn = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { barFill = 1 }
            animateCount(target: match.aiConf,  binding: { confValue = $0 }, delay: 0.30)
            animateCount(target: match.homePct, binding: { homeValue = $0 }, delay: 0.35)
            animateCount(target: match.drawPct, binding: { drawValue = $0 }, delay: 0.38)
            animateCount(target: match.awayPct, binding: { awayValue = $0 }, delay: 0.40)
            if match.isLive {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulseOpacity = 0.3 }
            }
        }
    }

    // ════════════════════════════════════════════════
    // MARK: Reusable Section Card
    // ════════════════════════════════════════════════
    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(white90)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // ════════════════════════════════════════════════
    // MARK: Team Stat Bar (Apple Sports visual bars)
    // ════════════════════════════════════════════════
    @ViewBuilder
    private func teamStatBar(label: String, homeVal: Int, awayVal: Int, homeLabel: String, awayLabel: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(homeLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(homeVal >= awayVal ? .white : white40)
                    .frame(width: 50, alignment: .leading)
                Spacer()
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(white40)
                Spacer()
                Text(awayLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(awayVal >= homeVal ? .white : white40)
                    .frame(width: 50, alignment: .trailing)
            }

            // Visual comparison bars
            GeometryReader { geo in
                let total = max(homeVal + awayVal, 1)
                let homeWidth = geo.size.width * CGFloat(homeVal) / CGFloat(total) * barFill
                let awayWidth = geo.size.width * CGFloat(awayVal) / CGFloat(total) * barFill

                HStack(spacing: 3) {
                    HStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(homeVal >= awayVal ? match.home.hex : match.home.hex.opacity(0.4))
                            .frame(width: max(4, homeWidth), height: 6)
                    }
                    HStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(awayVal >= homeVal ? match.away.hex : match.away.hex.opacity(0.4))
                            .frame(width: max(4, awayWidth), height: 6)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(white08).frame(height: 0.5), alignment: .bottom)
    }

    // ════════════════════════════════════════════════
    // MARK: Odds Table Row
    // ════════════════════════════════════════════════
    private func oddsTableRow(abbr: String, pct: String, odds: String, picked: Bool) -> some View {
        HStack(spacing: 0) {
            Text(abbr)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(picked ? green : white90)
                .frame(width: 80, alignment: .leading)
            Text(pct)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(white60)
                .frame(maxWidth: .infinity)
            Text(odds)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(white60)
                .frame(maxWidth: .infinity)
            Group {
                if picked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(green)
                } else {
                    Text("–")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(white20)
                }
            }
            .frame(width: 50)
        }
        .padding(.vertical, 10)
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

    private func matchInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(white40)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(white40)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(white90)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }

    // ════════════════════════════════════════════════════════
    // MARK: — F1 DETAIL CONTENT
    // ════════════════════════════════════════════════════════
    @ViewBuilder
    private var f1DetailContent: some View {

        // ── F1 HEADER ──
        ZStack(alignment: .top) {
            // Team color gradient background
            ZStack {
                LinearGradient(
                    colors: [match.home.hex.opacity(0.55), match.home.hex.opacity(0.15), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [Color.clear, Color.clear, bg.opacity(0.7), bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            HStack(alignment: .top, spacing: 0) {
                // Left: driver info
                VStack(alignment: .leading, spacing: 0) {
                    // Race badge
                    HStack(spacing: 5) {
                        Text(match.f1RaceFlag)
                            .font(.system(size: 12))
                        Text("RD \(match.f1RaceRound) · \(match.f1RaceName.uppercased())")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(white40)
                            .lineLimit(1)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 12)

                    // Team name
                    Text(match.f1TeamName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(match.home.hex)
                        .padding(.bottom, 4)

                    // Driver number + name
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("#\(match.f1DriverNumber)")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(match.home.hex.opacity(0.5))
                        Text(match.home.sub.uppercased())
                            .font(.system(size: 28, weight: .black))
                            .tracking(-0.5)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.bottom, 8)

                    // Nationality + position
                    HStack(spacing: 14) {
                        Text(match.f1Nationality)
                            .font(.system(size: 14))
                        HStack(spacing: 4) {
                            Text("P\(match.f1Position)")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                            Text("·")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(white20)
                            Text("\(match.f1Points) PTS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(match.home.hex)
                        }
                    }
                }
                .padding(.leading, 20)

                Spacer(minLength: 0)

                // Right: driver headshot
                if !match.home.logoURL.isEmpty, let url = URL(string: match.home.logoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 150, height: 180)
                                .clipped()
                                .mask(
                                    LinearGradient(
                                        colors: [.black, .black, .black.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        default:
                            Color.clear.frame(width: 150, height: 180)
                        }
                    }
                    .padding(.top, 30)
                }
            }
        }
        .frame(height: 260)

        // ── CIRCUIT TRACK VISUAL ──
        F1CircuitView(teamColor: match.home.hex, circuitName: match.f1CircuitName)
            .frame(height: 200)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)

        // ── 1. AI PREDICTION ──
        sectionCard("AI Prediction") {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("PREDICTED: P\(f1PredictedPosition(conf: match.aiConf))")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                    Text("\(confValue)% confidence · Podium \(match.homePct)%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(white40)
                }
                Spacer()
                Text("\(confValue)%")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(green)
            }
            .padding(.bottom, 12)

            Text(match.aiReason)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(white60)
                .lineSpacing(5)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(white08.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        // ── 2. BETTING ODDS ──
        sectionCard("Betting Odds") {
            VStack(spacing: 0) {
                f1OddsRow(label: "Race Winner", odds: match.homePct > 50 ? "2.10" : match.homePct > 30 ? "4.50" : String(format: "%.1f", 100.0 / max(1, Double(match.homePct))), highlight: match.homePct > 50)
                Rectangle().fill(white08).frame(height: 0.5)
                f1OddsRow(label: "Podium Finish", odds: match.homePct > 50 ? "1.30" : match.homePct > 30 ? "1.80" : "2.50", highlight: true)
                Rectangle().fill(white08).frame(height: 0.5)
                f1OddsRow(label: "Fastest Lap", odds: match.f1FastestLaps > 1 ? "5.00" : "8.00", highlight: false)
                Rectangle().fill(white08).frame(height: 0.5)
                f1OddsRow(label: "Points Finish", odds: "1.10", highlight: match.f1Position <= 5)
            }
        }

        // ── 3. SEASON STATS ──
        sectionCard("2025 Season Stats") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                f1SeasonStat(value: "\(match.f1Wins)", label: "WINS", color: match.home.hex)
                f1SeasonStat(value: "\(match.f1Podiums)", label: "PODIUMS", color: match.home.hex)
                f1SeasonStat(value: "\(match.f1Poles)", label: "POLES", color: match.home.hex)
                f1SeasonStat(value: "\(match.f1FastestLaps)", label: "FASTEST LAPS", color: .white)
                f1SeasonStat(value: "\(match.f1DNFs)", label: "DNFs", color: match.f1DNFs > 0 ? Color(hex: "#FF453A") : white40)
                f1SeasonStat(value: "\(match.f1Points)", label: "POINTS", color: match.home.hex)
            }
        }

        // ── 4. QUALIFYING & RACE PACE ──
        sectionCard("Performance") {
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(String(format: "P%.1f", match.f1AvgQualifying))
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(match.home.hex)
                    Text("AVG QUALIFYING")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(white40)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(white08).frame(width: 0.5, height: 50)

                VStack(spacing: 6) {
                    Text(String(format: "P%.1f", match.f1AvgFinish))
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("AVG FINISH")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(white40)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(white08).frame(width: 0.5, height: 50)

                VStack(spacing: 6) {
                    let diff = match.f1AvgQualifying - match.f1AvgFinish
                    Text(diff > 0 ? String(format: "+%.1f", diff) : String(format: "%.1f", diff))
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(diff > 0 ? green : Color(hex: "#FF453A"))
                    Text("RACE GAIN")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(white40)
                }
                .frame(maxWidth: .infinity)
            }
        }

        // ── 5. RECENT RACES ──
        if !match.f1RecentRaces.isEmpty {
            sectionCard("Recent Races") {
                ForEach(Array(match.f1RecentRaces.enumerated()), id: \.offset) { idx, race in
                    HStack(spacing: 12) {
                        Text(race.flag)
                            .font(.system(size: 16))
                        Text(race.race.uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(white90)
                            .lineLimit(1)
                        Spacer()
                        Text("P\(race.position)")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(race.position <= 3 ? match.home.hex : .white)
                        Text("\(race.points) pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(white40)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    if idx < match.f1RecentRaces.count - 1 {
                        Rectangle().fill(white08).frame(height: 0.5)
                    }
                }
            }
        }

        // ── 6. HEAD TO HEAD vs TEAMMATE ──
        if !match.f1TeammateAbbr.isEmpty {
            sectionCard("vs Teammate — \(match.f1TeammateName)") {
                HStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text(match.home.abbr)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(match.home.hex)

                        let qualParts = match.f1TeammateQualH2H.split(separator: "-")
                        let driverQual = Int(qualParts.first ?? "0") ?? 0
                        let tmQual = Int(qualParts.last ?? "0") ?? 0
                        f1H2HBar(left: driverQual, right: tmQual, label: "QUALIFYING", leftColor: match.home.hex)

                        let raceParts = match.f1TeammateRaceH2H.split(separator: "-")
                        let driverRace = Int(raceParts.first ?? "0") ?? 0
                        let tmRace = Int(raceParts.last ?? "0") ?? 0
                        f1H2HBar(left: driverRace, right: tmRace, label: "RACE FINISH", leftColor: match.home.hex)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }

        // ── 7. CIRCUIT HISTORY ──
        if !match.f1CircuitHistory.isEmpty {
            sectionCard("Circuit History — \(match.f1CircuitName)") {
                ForEach(Array(match.f1CircuitHistory.enumerated()), id: \.offset) { idx, result in
                    HStack {
                        Text(result.year)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(white60)
                        Spacer()
                        Text("P\(result.position)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(result.position <= 3 ? match.home.hex : .white)
                    }
                    .padding(.vertical, 8)
                    if idx < match.f1CircuitHistory.count - 1 {
                        Rectangle().fill(white08).frame(height: 0.5)
                    }
                }
            }
        }

        // ── 8. RACE INFO ──
        sectionCard("Race Info") {
            VStack(spacing: 0) {
                matchInfoRow(icon: "flag.checkered", label: "Circuit", value: match.f1CircuitName)
                Rectangle().fill(white08).frame(height: 0.5)
                matchInfoRow(icon: "arrow.trianglehead.counterclockwise.rotate.90", label: "Laps", value: "\(match.f1CircuitLaps)")
                Rectangle().fill(white08).frame(height: 0.5)
                matchInfoRow(icon: "ruler", label: "Track Length", value: match.f1CircuitLength)
                Rectangle().fill(white08).frame(height: 0.5)
                matchInfoRow(icon: "clock", label: "Race Start", value: match.f1RaceTime)
                if !match.broadcast.isEmpty {
                    Rectangle().fill(white08).frame(height: 0.5)
                    matchInfoRow(icon: "tv", label: "Watch", value: match.broadcast)
                }
            }
        }
    }

    // ── F1 Detail Helpers ──

    @ViewBuilder
    private func f1OddsRow(label: String, odds: String, highlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(white90)
            Spacer()
            Text(odds)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(highlight ? green : white60)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func f1SeasonStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundColor(white40)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(white08.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func f1H2HBar(left: Int, right: Int, label: String, leftColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(white40)
            GeometryReader { geo in
                let total = max(left + right, 1)
                let leftW = geo.size.width * CGFloat(left) / CGFloat(total)
                HStack(spacing: 2) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(leftColor)
                            .frame(width: max(20, leftW))
                        Text("\(left)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .padding(.leading, 6)
                    }
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(white20)
                        Text("\(right)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .padding(.trailing, 6)
                    }
                }
            }
            .frame(height: 26)
        }
    }

    // Convert AI confidence to predicted position
    private func f1PredictedPosition(conf: Int) -> String {
        switch conf {
        case 80...100: return "1"
        case 65...79: return "2"
        case 50...64: return "3"
        case 35...49: return "5"
        default: return "8"
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
