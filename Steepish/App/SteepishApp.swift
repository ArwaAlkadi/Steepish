//
//  StepGameApp.swift
//  StepGame
//

import SwiftUI

// MARK: - Main App

@main
struct SteepishApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var session = UserSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var connectivity = ConnectivityMonitor()

    init() {}

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(health)
                .environmentObject(connectivity)
                .onAppear {
                    AppDelegate.healthKitManager = health
                }
        }
    }
}

