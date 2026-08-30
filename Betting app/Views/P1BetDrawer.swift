//  P1BetDrawer.swift
//  Polymarket-style bottom drawer for logging a bet on a pick.
//
//  Collapsed it is a bar pinned to the bottom showing the call and the
//  payout multiple; drag it up (or tap it) and it expands into stake entry.
//  Drag down or tap the scrim to collapse. The drag tracks the finger, and
//  release snaps to whichever end it is closer to, with velocity taken into
//  account so a quick flick commits even from halfway.
//
//  IMPORTANT: this does NOT place a wager. Pick1 is not a sportsbook, and
//  that positioning is what keeps it runnable on Meta. The drawer writes a
//  row to `user_bets` through `BetTracker` — the user logging a bet they
//  placed elsewhere, so the app can show them their own P&L. Every label
//  says "track", never "place".

import SwiftUI

struct P1BetDrawer: View {
    let pick: Pick
    var accent: Color = .p1Lime
    /// Opens on the stake entry rather than the collapsed bar. Used when the
    /// user arrived by tapping "Track" on a game row: they already committed
    /// to the action, so making them find and drag the handle is friction.
    var startExpanded: Bool = false

    @StateObject private var tracker = BetTracker.shared
    @State private var expanded = false
    @State private var drag: CGFloat = 0
    @State private var stakeText = ""
    @FocusState private var amountFocused: Bool

    private let collapsedHeight: CGFloat = 92
    private let expandedHeight: CGFloat = 396
    private let quick: [Double] = [10, 25, 50, 100]

    private var isTracked: Bool { tracker.isTracked(pick.id) }
    private var stake: Double? {
        let cleaned = stakeText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    /// Live height while dragging, clamped to the two rest positions.
    private var height: CGFloat {
        let base = expanded ? expandedHeight : collapsedHeight
        return min(max(base - drag, collapsedHeight), expandedHeight)
    }
    private var openness: Double {
        Double((height - collapsedHeight) / (expandedHeight - collapsedHeight))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim only once the drawer is meaningfully open, so the
            // collapsed bar never blocks the page behind it.
            Color.black
                .opacity(0.55 * openness)
                .ignoresSafeArea()
                .allowsHitTesting(openness > 0.5)
                .onTapGesture { setExpanded(false) }

            drawer
        }
        .task { if !tracker.loaded { await tracker.load() } }
        .onAppear {
            if startExpanded && !expanded {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { expanded = true }
            }
        }
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.p1Line2)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            collapsedBar

            if openness > 0.02 {
                expandedBody
                    .opacity(openness)
                    .frame(height: max(0, height - collapsedHeight - 10), alignment: .top)
                    .clipped()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(Color.p1Panel)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .strokeBorder(Color.p1Line, lineWidth: 1)
                .ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: -8)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { drag = $0.translation.height * -1 }
                .onEnded { g in
                    // A fast flick commits regardless of distance; otherwise
                    // snap to the nearer end.
                    let velocity = -g.predictedEndTranslation.height + g.translation.height
                    drag = 0
                    if abs(velocity) > 180 {
                        setExpanded(velocity > 0)
                    } else {
                        setExpanded(openness > 0.5)
                    }
                }
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: expanded)
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { expanded = value }
        if !value { amountFocused = false }
    }

    // MARK: Collapsed bar

    private var collapsedBar: some View {
        Button { setExpanded(!expanded) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isTracked ? "TRACKING" : "TRACK YOUR BET")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(1.44)
                        .foregroundStyle(isTracked ? accent : Color.p1Mute)
                    Text(pick.shortDisplayPick.uppercased())
                        .font(.anton(19))
                        .foregroundStyle(Color.p1Foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.2f×", pick.decimalOdds))
                        .font(.mono(15, weight: .bold))
                        .foregroundStyle(accent)
                    Text("PAYOUT")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(1.12)
                        .foregroundStyle(Color.p1Mute)
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.p1Ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent))
                    .rotationEffect(.degrees(openness * 180))
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Expanded body

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log the stake you placed elsewhere. Pick1 does not take bets — this only builds your own record.")
                .font(.archivo(12))
                .lineSpacing(3)
                .foregroundStyle(Color.p1Mute)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(quick, id: \.self) { amt in
                    let on = stakeText == String(Int(amt))
                    Button { stakeText = String(Int(amt)) } label: {
                        Text("$\(Int(amt))")
                            .font(.archivo(14, weight: .bold))
                            .foregroundStyle(on ? Color.p1Ink : Color.p1Ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).fill(on ? accent : Color.p1Panel2))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text("$").font(.anton(20)).foregroundStyle(Color.p1Mute)
                TextField("Amount", text: $stakeText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.anton(20))
                    .foregroundStyle(Color.p1Foreground)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Panel2))

            HStack {
                Text("IF IT HITS, YOU GET BACK")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.44)
                    .foregroundStyle(Color.p1Mute)
                Spacer(minLength: 8)
                Text(stake.map { "$\(Int(($0 * pick.decimalOdds).rounded()))" } ?? "—")
                    .font(.anton(18))
                    .foregroundStyle(accent)
            }

            Button {
                Task {
                    await tracker.track(pick: pick, stake: stake)
                    setExpanded(false)
                }
            } label: {
                Text(stake == nil ? "TRACK WITHOUT A STAKE" : "TRACK THIS BET")
                    .font(.archivoNarrow(13, weight: .bold))
                    .tracking(1.56)
                    .foregroundStyle(Color.p1Ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent))
            }
            .buttonStyle(.plain)

            if isTracked {
                Button {
                    Task {
                        await tracker.untrack(pickId: pick.id)
                        setExpanded(false)
                    }
                } label: {
                    Text("STOP TRACKING")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.p1Hot)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}
