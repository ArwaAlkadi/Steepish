//
//  FirebaseService.swift
//  StepGame
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class FirebaseService {

    static let shared = FirebaseService()
    private init() {}

    let db = Firestore.firestore()

    /// Generates a random 6-character join code.
    static func generateJoinCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }
}
