//
//  Firebase+Notifications.swift
//  StepGame
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

extension FirebaseService {

    /// Saves the FCM token for the current user.
    func saveFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("players").document(uid).setData(
            ["fcmToken": token],
            merge: true
        )
    }

    /// Logs notification events to Firestore for debugging silent push delivery.
    func logNotificationEvent(type: String, payload: [AnyHashable: Any] = [:]) async {
        let uid = Auth.auth().currentUser?.uid ?? "unknown"

        var safePayload: [String: Any] = [:]
        for (key, value) in payload {
            safePayload[String(describing: key)] = String(describing: value)
        }

        let data: [String: Any] = [
            "uid": uid,
            "type": type,
            "payload": safePayload,
            "createdAt": FieldValue.serverTimestamp(),
            "deviceName": UIDevice.current.name,
            "systemVersion": UIDevice.current.systemVersion
        ]

        do {
            try await db.collection("notificationDebugLogs").addDocument(data: data)
            print("📝 Debug log saved:", type)
        } catch {
            print("❌ Failed to save notification debug log:", error)
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let navigateToChallenge = Notification.Name("navigateToChallenge")
}
