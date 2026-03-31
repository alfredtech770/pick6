//
//  ContentView.swift
//  Betting app
//
//  Created by Ethan on 3/9/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayPicksView()
                .tabItem {
                    Label("Picks", systemImage: "flame.fill")
                }

            // Your other tabs here
        }
        .tint(Color(hex: "#22C55E"))
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
