// Pick1AccountComponents.swift
// Reusable building blocks for Wins / Live / Profile (account pages).
// Designed to mirror the spec components from
// `Pick6 Account Pages.html` exactly: LimeToggle (capsule + sliding
// knob), StatusPill (good/mid/bad pill), StatTile (label/value/trend/
// sparkline), Sparkline, DashedLine.

import SwiftUI

// ════════════════════════════════════════════════════════════════
// MARK: - LimeToggle
// ════════════════════════════════════════════════════════════════

/// 36×22 capsule with an 18×18 sliding knob. Lime when on,
/// `--line-2` when off. Used in Profile → Settings → Notifications,
/// Dark Mode, etc.
struct LimeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color(hex: "#D4FF3A") : Color(hex: "#2D3038"))
            .frame(width: 36, height: 22)
            .overlay(
                Circle()
                    .fill(isOn ? Color(hex: "#0A0B0D") : Color(hex: "#F5F3EE"))
                    .frame(width: 18, height: 18)
                    .offset(x: isOn ? 7 : -7)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) { isOn.toggle() }
            }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - StatusPill (LiveCard footer)
// ════════════════════════════════════════════════════════════════

/// 3 variants matching the spec's `.status-pill`:
///   • .good (lime green)  — "ON TRACK"
///   • .mid (lime yellow)  — "HITTING"
///   • .bad (hot red)      — "COOLING"
struct StatusPill: View {
    enum Kind {
        case good, mid, bad
        var label: String {
            switch self {
            case .good: return "ON TRACK"
            case .mid:  return "HITTING"
            case .bad:  return "COOLING"
            }
        }
        var fg: Color {
            switch self {
            case .good: return Color(hex: "#4ade80")
            case .mid:  return Color(hex: "#D4FF3A")
            case .bad:  return Color(hex: "#FF5A36")
            }
        }
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(kind.fg).frame(width: 5, height: 5)
            Text(kind.label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.6)
        }
        .foregroundColor(kind.fg)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(kind.fg.opacity(0.10)))
        .overlay(Capsule().stroke(kind.fg.opacity(0.28), lineWidth: 1))
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - StatTile (Profile → Stats tab)
// ════════════════════════════════════════════════════════════════

/// One of the 4 stat tiles on Profile → Stats. Spec layout:
///   label (9pt narrow caps mute)
///   value (Anton 28pt) + optional unit small
///   trend (▲/▼ + delta, mono 10pt, win/loss/mute color)
///   sparkline (26pt high)
struct StatTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var trend: String? = nil
    var trendUp: Bool? = nil
    var valueColor: Color = Color(hex: "#F5F3EE")
    var sparkColor: Color = Color(hex: "#B9B7B0")
    var pts: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.anton(28))
                    .foregroundColor(valueColor)
                if let unit = unit {
                    Text(unit)
                        .font(.archivo(13, weight: .heavy))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
            if let t = trend {
                HStack(spacing: 4) {
                    Image(systemName: trendUp == true ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .heavy))
                    Text(t)
                        .font(.mono(10, weight: .bold))
                }
                .foregroundColor(trendUp == true ? Color(hex: "#4ade80")
                                 : trendUp == false ? Color(hex: "#FF5A36")
                                 : Color(hex: "#6E6F75"))
            }
            if !pts.isEmpty {
                Sparkline(pts: pts, color: sparkColor)
                    .frame(height: 22)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#101114"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
                )
        )
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Sparkline
// ════════════════════════════════════════════════════════════════

/// Single-stroke sparkline. Min/max-normalised so the wave fills the
/// available height. Mirrors the spec's `<Spark>` component.
struct Sparkline: View {
    let pts: [Double]
    var color: Color = Color(hex: "#D4FF3A")

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard let mn = pts.min(),
                      let mx = pts.max(),
                      pts.count > 1 else { return }
                let span = max(mx - mn, 0.001)
                let dx = geo.size.width / CGFloat(pts.count - 1)
                let h = geo.size.height
                for (i, v) in pts.enumerated() {
                    let y = h - (CGFloat((v - mn) / span) * (h - 2)) - 1
                    let pt = CGPoint(x: CGFloat(i) * dx, y: y)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            .stroke(color, style: .init(lineWidth: 1.6,
                                        lineCap: .round,
                                        lineJoin: .round))
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - DashedLine
// ════════════════════════════════════════════════════════════════

/// Horizontal dashed line, used on WonCard footer + LiveCard footer.
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
