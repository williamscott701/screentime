//
//  ContentView.swift
//  screentime
//
//  Created by Willam Scott on 01/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ScreenTimeManager.shared

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "clock.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .environmentObject(manager)
    }
}

#Preview {
    ContentView()
}
