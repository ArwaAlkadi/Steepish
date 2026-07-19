//
//  Firebase+AppConfig.swift
//  Steepish
//

import Foundation
import FirebaseFirestore

// MARK: - App Config

extension FirebaseService {

    /// Fetches the minimum required app version from Firestore.
    func fetchAppConfig() async throws -> AppConfig {
        let doc = try await db.collection("app_config")
            .document("version")
            .getDocument()

        guard doc.exists else {
            throw NSError(domain: "AppConfig", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Version config not found"])
        }

        let data = doc.data() ?? [:]

        return AppConfig(
            minimumVersion: data["minimum"] as? String ?? "1.0.0",
            message: data["message"] as? String ?? "Please update to continue"
        )
    }
}

