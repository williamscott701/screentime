//
//  ContentView.swift
//  ScreenDash
//
//  Created by Willam Scott on 01/04/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ScreenDriftStore.self) var store

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Today", systemImage: "clock.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
}
