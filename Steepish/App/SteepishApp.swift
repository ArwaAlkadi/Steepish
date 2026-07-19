//
//  SteepishApp.swift
//  Steepish
//

import SwiftUI

// MARK: - Main App

/// App entry point: wires up the shared session/health/connectivity environment objects
/// and hosts `RootView`.
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

