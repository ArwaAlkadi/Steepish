//
//  NotificationService.swift
//  StepGame
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let db = Firestore.firestore()

    func saveToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("players").document(uid).setData(
            ["fcmToken": token],
            merge: true
        )
    }
}
