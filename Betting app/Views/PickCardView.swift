//
//  PickCardView.swift
//  Betting app
//
//  Created by Ethan on 3/30/26.
//

import SwiftUI

struct PickCardView: View {
    let pick: Pick

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#0f1117"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 12) {

                // Header — League + Confidence
                HStack {
                    Text(pick.league.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)

                    Spacer()

                    Text(pick.confidence)
                        .font(.caption)
                }

                // Teams
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pick.homeTeam)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("vs")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(pick.awayTeam)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Probability — Hero element
                    VStack(spacing: 2) {
                        Text("\(Int(pick.probability))%")
                            .font(.system(size: 42,
                                          weight: .black,
                                          design: .default))
                            .italic()
                            .foregroundColor(Color(hex: "#22C55E"))
                            .shadow(color: Color(hex: "#22C55E").opacity(0.5),
                                    radius: 8)

                        Text("confidence")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // Pick
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(Color(hex: "#22C55E"))
                        .font(.caption)
                    Text("Pick: \(pick.pick)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    resultBadge
                }

                // Reasoning
                Text(pick.reasoning)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(20)
        }
        .padding(.horizontal)
    }

    // Result badge
    @ViewBuilder
    var resultBadge: some View {
        switch pick.result {
        case "win":
            Label("WIN", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#22C55E"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#22C55E").opacity(0.15))
                .cornerRadius(8)

        case "loss":
            Label("LOSS", systemImage: "xmark.circle.fill")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)

        default:
            Text("PENDING")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
        }
    }

    var borderColor: Color {
        switch pick.result {
        case "win": return Color(hex: "#22C55E").opacity(0.5)
        case "loss": return Color.red.opacity(0.3)
        default: return Color.white.opacity(0.08)
        }
    }
}
