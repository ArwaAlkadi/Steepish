//
//  StepGameApp.swift
//  StepGame
//
//

import SwiftUI
import FirebaseCore

@main
struct StepGameApp: App {

    // MARK: - State Objects
    @StateObject private var session = GameSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var connectivity = ConnectivityMonitor()

    // MARK: - Init
    init() {
        FirebaseApp.configure()
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(health)
                .environmentObject(connectivity)
        }
    }
}


// MARK: - ConnectivityMonitor
import Foundation
import Network
import Combine

@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
