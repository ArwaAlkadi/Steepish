//
//  AppConfig.swift
//  Steepish
//

import Foundation

/// Remote configuration values used to gate app functionality (e.g. minimum supported version).
struct AppConfig {

    // MARK: - Properties

    /// The minimum app version required to use the app.
    let minimumVersion: String

    /// The message to display to the user when an update is required.
    let message: String
}

