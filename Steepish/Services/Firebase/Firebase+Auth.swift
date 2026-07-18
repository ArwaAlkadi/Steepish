//
//  Firebase+Auth.swift
//  StepGame
//

import Foundation
import FirebaseAuth

extension FirebaseService {

    /// Signs in anonymously if no current user exists, returns the UID.
    func signInIfNeeded() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
}
