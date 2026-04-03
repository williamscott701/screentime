//
//  ScreenDriftApp.swift
//  ScreenDrift
//
//  Created by Willam Scott on 01/04/26.
//

import SwiftUI
import FamilyControls

@main
struct ScreenDriftApp: App {
    @State private var store = ScreenDriftStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.requestAuthorization()
                }
        }
    }
}
