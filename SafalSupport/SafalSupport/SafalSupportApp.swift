//
//  SafalSupportApp.swift
//  SafalSupport
//
//  Created by Apple on 16/10/25.
//

import SwiftUI

@main
struct SafalSupportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var appState = AppState()
    @StateObject var qaManager = QuickActionsManager.instance
   
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(qaManager)
                .withThemeColors() // Apply accent color globally
                .id("App-\(appState.isAuthenticated)")
        }
    }
}
