//
//  ConnectivityMonitor.swift
//  Steepish
//

import Network
import Combine

// MARK: - Connectivity Monitor

/// Observes network reachability and publishes online/offline state for the UI to react to.
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

