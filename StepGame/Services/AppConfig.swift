//
//  AppConfig.swift
//  StepGame
//

import Foundation
import FirebaseFirestore

struct AppConfig {
    let minimumVersion: String
    let message: String
    
    static func fetch() async throws -> AppConfig {
        let doc = try await Firestore.firestore()
            .collection("app_config")
            .document("version")
            .getDocument()
        
        guard doc.exists else {
            throw NSError(
                domain: "AppConfig",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Version config not found"]
            )
        }
        
        let data = doc.data() ?? [:]
        
        return AppConfig(
            minimumVersion: data["minimum"] as? String ?? "1.0.0",
            message: data["message"] as? String ?? "Please update to continue"
        )
    }
}

extension String {
    func isOlderThan(_ version: String) -> Bool {
        return self.compare(version, options: .numeric) == .orderedAscending
    }
}
