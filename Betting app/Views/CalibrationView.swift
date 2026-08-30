// CalibrationView.swift
// "Do we mean it?" — proof that Pick1's stated confidence matches reality.
// Reads the public `calibration_bands` view (stated-confidence band →
// actual hit rate, all-time, from graded picks) and renders each band as
// a paired bar: what we said vs what actually happened. No competitor
// shows this; it's honest by construction (straight from the ledger).

import SwiftUI
import Combine
import Supabase

struct CalibrationBand: Codable, Identifiable {
    let band: String
    let n: Int
    let wins: Int
    let actualPct: Double
    let avgStated: Double

    var id: String { band }

    enum CodingKeys: String, CodingKey {
        case band, n, wins
        case actualPct = "actual_pct"
        case avgStated = "avg_stated"
    }
}

@MainActor
final class CalibrationModel: ObservableObject {
    @Published var bands: [CalibrationBand] = []
    @Published var loaded = false

    func load() async {
        do {
            let rows: [CalibrationBand] = try await SupabaseManager.client
                .from("calibration_bands").select().execute().value
            // Highest confidence band first.
            bands = rows.sorted { $0.avgStated > $1.avgStated }
        } catch { }
        loaded = true
    }

    /// The "within N points" honesty headline, weighted by sample size.
    var avgGapText: String? {
        guard !bands.isEmpty else { return nil }
        let totalN = bands.reduce(0) { $0 + $1.n }
        guard totalN > 0 else { return nil }
        let weightedGap = bands.reduce(0.0) { acc, b in
            acc + abs(b.avgStated - b.actualPct) * Double(b.n)
        } / Double(totalN)
        return String(format: "%.0f", weightedGap)
    }
}

struct CalibrationCard: View {
    @StateObject private var model = CalibrationModel()
    private let lime = Color(red: 0.776, green: 1.0, blue: 0.204)

    var body: some View {
        Group {
            if model.bands.count >= 2 {
                card
            } else if !model.loaded {
                ProgressView().tint(Color(hex: "#6E6F75"))
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            }
        }
        .task { if !model.loaded { await model.load() } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t(.rd_cal_title))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(t(.rd_cal_tagline))
                    .font(.anton(19)).foregroundColor(Color(hex: "#F5F3EE"))
                if let gap = model.avgGapText {
                    Text("\(t(.rd_cal_gap_pre))\(gap)\(t(.rd_cal_gap_post))")
                        .font(.archivo(12)).foregroundColor(Color(hex: "#8A8D94"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 12) {
                ForEach(model.bands) { b in
                    bandRow(b)
                }
            }
            .padding(.top, 4)

            // Legend
            HStack(spacing: 14) {
                legendDot(Color(hex: "#4A4B50"), t(.rd_cal_we_said))
                legendDot(lime, t(.rd_cal_actually_hit))
                Spacer()
                Text(t(.rd_cal_alltime))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.0)
                    .foregroundColor(Color(hex: "#4A4B50"))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1E1E1E")))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#292929"), lineWidth: 1))
    }

    private func bandRow(_ b: CalibrationBand) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(b.band).font(.archivo(12, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                Text(t(.rd_cal_pct_hit, count: Int(b.actualPct.rounded())))
                    .font(.archivo(12, weight: .bold)).foregroundColor(lime)
                Text("· n=\(b.n)")
                    .font(.archivo(11)).foregroundColor(Color(hex: "#4A4B50"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // "We said" (muted, behind)
                    Capsule().fill(Color(hex: "#2A2D33"))
                        .frame(width: geo.size.width * CGFloat(b.avgStated / 100.0), height: 6)
                    // "Actually hit" (lime, front)
                    Capsule().fill(lime)
                        .frame(width: geo.size.width * CGFloat(b.actualPct / 100.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(label).font(.archivoNarrow(9, weight: .bold)).tracking(0.8)
                .foregroundColor(Color(hex: "#8A8D94"))
        }
    }
}
