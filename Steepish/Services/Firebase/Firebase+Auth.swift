//
//  Firebase+Auth.swift
//  Steepish
//

import Foundation
import FirebaseAuth

// MARK: - Auth

extension FirebaseService {

    /// Signs in anonymously if no current user exists, returns the UID.
    func signInIfNeeded() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}

