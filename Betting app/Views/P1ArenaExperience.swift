import SwiftUI
import AVFoundation

@MainActor enum P1ArenaAudio {
    private static var player: AVAudioPlayer?
    static func play(_ name: String) {
        guard UserDefaults.standard.bool(forKey: "pick1SoundsEnabled"),
              let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.45
            player?.play()
        } catch { /* Sound is optional; interaction remains available. */ }
    }
}

struct P1ArenaBackdrop: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.p1Ink
            RadialGradient(colors: [Color.p1Lime.opacity(0.025), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color.p1Primary.opacity(0.025), .clear], center: .topTrailing, startRadius: 0, endRadius: 330)
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct P1SettledWinReveal: View {
    let pick: Pick
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrating = false
    @State private var travel = false
    @State private var feedback = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CONFIRMED PICK1 WIN", systemImage: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color.p1Lime)
            Text(pick.displayPick).font(.system(size: 24, weight: .heavy))
            Text(p1LeagueLabel(pick) + " · " + pick.gameDate).font(.system(size: 11)).foregroundStyle(Color.p1Ink2)
            Text("Graded result, published in the public record.")
                .font(.system(size: 10)).foregroundStyle(Color.p1Ink2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(LinearGradient(colors: [Color.p1Lime.opacity(0.12), Color.p1Panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.p1Lime.opacity(celebrating ? 0.8 : 0.25)))
            .shadow(color: Color.p1Lime.opacity(celebrating ? 0.22 : 0), radius: 18)
            .overlay {
                if celebrating && !reduceMotion {
                    GeometryReader { geo in
                        ForEach(0..<16, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i % 3 == 0 ? Color.white : Color.p1Lime)
                                .frame(width: 4, height: 7)
                                .rotationEffect(.degrees(travel ? Double(i * 37) : 0))
                                .position(x: geo.size.width * Double(i + 1) / 17, y: travel ? geo.size.height + 12 : -8)
                                .opacity(travel ? 0 : 0.9)
                        }
                    }.clipped().allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .sensoryFeedback(.success, trigger: feedback)
            .task(id: pick.id) {
                guard pick.isWin, !pick.isPending else { return }
                var seen = UserDefaults.standard.stringArray(forKey: "pick1CelebratedResults") ?? []
                guard !seen.contains(pick.id.uuidString) else { return }
                seen.append(pick.id.uuidString)
                UserDefaults.standard.set(Array(seen.suffix(128)), forKey: "pick1CelebratedResults")
                feedback += 1
                P1ArenaAudio.play("pick1-win")
                guard !reduceMotion else { return }
                celebrating = true
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                withAnimation(.easeOut(duration: 1.1)) { travel = true }
                do { try await Task.sleep(for: .milliseconds(1150)) } catch { return }
                withAnimation(.easeOut(duration: 0.25)) { celebrating = false }
            }
    }
}

struct P1RecentWins: View {
    let picks: [Pick]
    var onOpen: (Pick) -> Void
    private var wins: [Pick] { Array(picks.filter { $0.isWin && !$0.isPending }.prefix(6)) }
    var body: some View {
        if !wins.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("RECENT SETTLED WINS", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color.p1Lime)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(wins) { pick in
                            Button { onOpen(pick) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(p1LeagueLabel(pick) + " · " + pick.gameDate).font(.system(size: 9)).foregroundStyle(Color.p1Ink2)
                                    Text(pick.shortDisplayPick).font(.system(size: 19, weight: .heavy)).lineLimit(1)
                                    if let price = P1BookQuote.forPick(pick) {
                                        Text(String(format: "at %.2f market odds", price.odds)).font(.system(size: 11, weight: .semibold))
                                        Text("+" + (100 * (price.odds - 1)).formatted(.currency(code: "USD").precision(.fractionLength(0)))).font(.system(size: 24, weight: .heavy)).foregroundStyle(Color.p1Lime)
                                        Text("On a $100-a-pick basis").font(.system(size: 9)).foregroundStyle(Color.p1Ink2)
                                    } else {
                                        Text("Prediction won").font(.system(size: 10)).foregroundStyle(Color.p1Ink2)
                                    }
                                }.foregroundStyle(.white).frame(width: 220, alignment: .leading).padding(16)
                                    .background(Color.p1Panel, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.p1Lime.opacity(0.22)))
                            }.buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                Text("Highlights only. The complete record, including losses, is below.").font(.system(size: 10)).foregroundStyle(Color.p1Ink2)
            }.padding(.horizontal, 22).padding(.top, 18)
        }
    }
}
