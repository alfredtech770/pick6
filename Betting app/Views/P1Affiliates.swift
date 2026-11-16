import SwiftUI
import Combine
import StoreKit
import Supabase

// MARK: Licensed bookmaker handoff
// "Place this pick" on the game page and "Place your watchlist" on the slip:
// a sheet listing the bookmakers PICK1 has an affiliate link with that are
// licensed where the user is. Partners live in Supabase `affiliate_partners`
// (edited there, no release needed). Nothing shows anywhere until a partner
// with a real https link is enabled for the user's jurisdiction, and the
// first open asks for legal age. PICK1 never takes a stake: the user
// recreates the selection at the bookmaker.

struct P1Bookmaker: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let markets: [String]
    let affiliateURL: String?
    let logoURL: String?
    let licence: String?
    let sort: Int

    enum CodingKeys: String, CodingKey {
        case id, name, markets, licence, sort
        case affiliateURL = "affiliate_url", logoURL = "logo_url"
    }

    /// The issued link, opened verbatim. Only plain https, never a placeholder.
    var destination: URL? {
        guard let s = affiliateURL, let url = URL(string: s), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              !host.hasSuffix(".example"), host != "example.com" else { return nil }
        return url
    }
    static func key(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
}

@MainActor
final class P1AffiliateStore: ObservableObject {
    static let shared = P1AffiliateStore()
    @Published private(set) var partners: [P1Bookmaker] = []
    /// "FR", "US-NJ", "CA-ON"; empty until known.
    @Published private(set) var market = ""
    private var loaded = false

    /// Partners licensed and linked for where the user is.
    var available: [P1Bookmaker] {
        guard !market.isEmpty else { return [] }
        return partners.filter { $0.id != P1AffiliateStore.spreadID && $0.destination != nil && $0.markets.contains(market) }.sorted { $0.sort < $1.sort }
    }

    /// Spread (the prop firm's free first bet) is switched from the same table, no release
    /// needed: row id "spread", on while `enabled` and its link is https (the table's own
    /// read policy). markets ["*"] means everywhere; otherwise country codes ("US", "FR").
    /// Spread itself refuses the regions it does not serve, at signup.
    static let spreadID = "spread"
    var spreadOn: Bool {
        guard let s = partners.first(where: { $0.id == Self.spreadID }), s.destination != nil else { return false }
        if s.markets.contains("*") { return true }
        let country = String(market.prefix(2))
        return !country.isEmpty && s.markets.contains(country)
    }
    var isAvailable: Bool { !available.isEmpty }

    func load() async {
        guard !loaded else { return }
        loaded = true
        async let rows: [P1Bookmaker] = (try? SupabaseManager.client.from("affiliate_partners")
            .select("id, name, markets, affiliate_url, logo_url, licence, sort").execute().value) ?? []
        partners = await rows
        // Nothing to place anywhere: skip locating the user entirely.
        guard partners.contains(where: { $0.destination != nil }) else { return }
        market = await Self.resolveMarket(needsSubdivision: partners.contains { $0.markets.contains { $0.contains("-") } })
    }

    /// Country from the App Store storefront (no network). The US and Canada
    /// license per state or province, so there an approximate IP region is
    /// read too, only when a partner needs it. This is availability, not an
    /// eligibility check: the bookmaker verifies age and location itself.
    private static func resolveMarket(needsSubdivision: Bool) async -> String {
        #if DEBUG
        if let i = CommandLine.arguments.firstIndex(of: "-affiliateMarket"), i + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[i + 1]
        }
        #endif
        let storefront = await Storefront.current?.countryCode   // ISO 3166 alpha-3
        let alpha2: [String: String] = ["FRA": "FR", "USA": "US", "CAN": "CA", "GBR": "GB", "BEL": "BE", "ESP": "ES",
                                        "ITA": "IT", "DEU": "DE", "BRA": "BR", "MEX": "MX"]
        let country = storefront.flatMap { alpha2[$0] } ?? Locale.current.region?.identifier ?? ""
        guard country == "US" || country == "CA" else { return country }
        guard needsSubdivision else { return "" }
        struct Region: Decodable { let country_code: String; let region_code: String? }
        guard let url = URL(string: "https://ipapi.co/json/"),
              let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 8)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let region = try? JSONDecoder().decode(Region.self, from: data),
              region.country_code.uppercased() == country, let sub = region.region_code, !sub.isEmpty else { return "" }
        return country + "-" + sub.uppercased()
    }
}

/// One selection handed to the bookmaker: the pick itself or one of its markets.
struct P1Selection: Identifiable {
    let id: String
    let market: String
    let value: String
    let probability: Int?
    let game: String
    let books: [OddsBook]
    /// The price PICK1 captured for this selection, when there is one.
    var price: Double? = nil
    /// For the Spread handoff: the two teams and the side picked, so Spread can
    /// find the same game on its board. Nil where the selection is not a winner pick.
    var spreadHome: String? = nil
    var spreadAway: String? = nil
    var spreadPick: String? = nil
}

extension Pick {
    var handoffSelection: P1Selection {
        P1Selection(id: id.uuidString, market: "To win", value: displayPick, probability: Int(probability.rounded()),
                    game: "\(awayTeam) @ \(homeTeam)", books: oddsBooks ?? [], price: P1BookQuote.forPick(self)?.odds,
                    spreadHome: homeTeam, spreadAway: awayTeam, spreadPick: pick)
    }
}

/// The button, shown only where a licensed partner exists.
struct P1PlaceButton: View {
    let title: String
    let selections: [P1Selection]
    let source: String
    @ObservedObject private var store = P1AffiliateStore.shared
    @AppStorage("pick1.legalAgeConfirmed") private var ageConfirmed = false
    @State private var askAge = false
    @State private var showing = false

    init(_ title: String, selections: [P1Selection], source: String) {
        self.title = title; self.selections = selections; self.source = source
    }

    var body: some View {
        // A VStack, not a Group: an empty Group is no view at all, so its
        // .task never ran and the partners were never loaded.
        VStack(spacing: 0) {
            if store.isAvailable && !selections.isEmpty {
                Button {
                    Analytics.track("affiliate_cta_tapped", ["source": source, "selections": selections.count, "market": store.market])
                    if ageConfirmed { showing = true } else { askAge = true }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "ticket.fill").font(.system(size: 16, weight: .bold))
                        Text(title).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text("\(store.available.count) licensed").font(.system(size: 13)).foregroundStyle(Color.black.opacity(0.6))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18).frame(height: 50)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .task { await store.load() }
        .confirmationDialog("Are you of legal betting age where you live?", isPresented: $askAge, titleVisibility: .visible) {
            Button("Yes, I am") { ageConfirmed = true; showing = true }
            Button("No", role: .cancel) {}
        } message: {
            Text("Bookmakers only accept adults (18+ in France, 21+ in most US states).")
        }
        .sheet(isPresented: $showing) {
            P1BookmakerSheet(title: title, selections: selections, source: source)
        }
    }
}

struct P1BookmakerSheet: View {
    let title: String
    let selections: [P1Selection]
    let source: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = P1AffiliateStore.shared
    @State private var failed = false

    private var french: Bool { store.market == "FR" }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title.replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression))
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 36, height: 36)
                    }.accessibilityLabel("Close")
                    Spacer()
                }
            }.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 14)
            Rectangle().fill(P1Board.pill).frame(height: 1).padding(.horizontal, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if P1SpreadPromo.enabled {
                        if selections.count == 1, let one = selections.first, one.spreadPick != nil {
                            P1SpreadPickCard(selection: one)
                        } else {
                            P1SpreadSlipCard()
                        }
                    }
                    Text("Licensed in your country").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                    ForEach(store.available) { partnerRow($0) }
                    Text(selections.count > 1 ? "Your \(selections.count) selections" : "Your selection")
                        .font(.system(size: 14)).foregroundStyle(P1Board.secondary).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(selections) { sel in
                            HStack(alignment: .top, spacing: 12) {
                                Text("PICK1").font(.system(size: 10, weight: .heavy)).foregroundStyle(.black)
                                    .padding(.horizontal, 5).padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.p1Lime)).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sel.value).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                    Text(sel.market + " · " + sel.game).font(.system(size: 12)).foregroundStyle(P1Board.secondary).lineLimit(2)
                                }
                                Spacer()
                                if let p = sel.probability {
                                    Text("\(p)%").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.p1Lime).monospacedDigit()
                                }
                            }.padding(.vertical, 12)
                            if sel.id != selections.last?.id { Rectangle().fill(P1Board.pill).frame(height: 1) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
                    .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))


                    Text(selections.count > 1
                         ? "Open the bookmaker and add these selections yourself. The link does not carry your watchlist over."
                         : "Open the bookmaker and find this selection. Check the current price before you confirm.")
                        .font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                    Text(disclaimer).font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                }.padding(16).padding(.bottom, 20)
            }
        }
        .background(P1Board.card.opacity(0.0).background(Color(hex: "#0B0B0B")).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(28)
        .onAppear { Analytics.track("affiliate_sheet_viewed", ["source": source, "selections": selections.count, "market": store.market]) }
        .alert("Could not open the bookmaker", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }

    /// Legal lines per market: France requires the ANJ prevention message.
    private var disclaimer: String {
        var s = "Affiliate links: PICK1 may earn a commission. Bets are placed with the bookmaker, who checks your age and location. No prediction guarantees a win."
        if french {
            s += " Jouer comporte des risques : endettement, dépendance… Appelez le 09 74 75 13 13 (appel non surtaxé)."
        } else if store.market.hasPrefix("US") {
            s += " Gambling problem? Call 1-800-GAMBLER."
        } else if store.market.hasPrefix("CA") {
            s += " Need help? ConnexOntario 1-866-531-2600."
        }
        return s
    }

    private func price(_ partner: P1Bookmaker) -> Double? {
        guard selections.count == 1 else { return nil }
        return selections[0].books.filter { P1Bookmaker.key($0.book) == P1Bookmaker.key(partner.name) && $0.odds > 1 }.map(\.odds).max()
    }

    private func partnerRow(_ partner: P1Bookmaker) -> some View {
        Button {
            guard let url = partner.destination else { return }
            Analytics.track("affiliate_outbound_tapped", ["partner_id": partner.id, "source": source, "market": store.market, "selections": selections.count])
            openURL(url) { ok in
                if ok { Analytics.track("affiliate_outbound_opened", ["partner_id": partner.id, "source": source, "market": store.market]) }
                else { failed = true }
            }
        } label: {
            HStack(spacing: 14) {
                Group {
                    if ["Betclic", "Unibet", "Winamax", "PMU"].contains(partner.name) {
                        Image("Bookie_" + partner.name).resizable().scaledToFit()
                    } else if let l = partner.logoURL, let url = URL(string: l) {
                        CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    } else {
                        Text(String(partner.name.prefix(1))).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(P1Board.pill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(partner.name).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                    if let licence = partner.licence {
                        Text("Licensed · \(licence)").font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                    }
                }
                Spacer()
                if let p = price(partner) {
                    Text(String(format: "%.2f", p)).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.p1Lime)
                        .monospacedDigit().padding(.horizontal, 10).frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(P1Board.pill))
                }
                Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .bold)).foregroundStyle(P1Board.secondary)
            }
            .padding(.horizontal, 14).frame(height: 68)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
        }.buttonStyle(PressableButtonStyle())
    }
}
