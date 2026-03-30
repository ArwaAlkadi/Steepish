//
//  NotificationDebugService.swift
//  StepGame
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class NotificationDebugService {

    static let shared = NotificationDebugService()
    private init() {}

    private let db = Firestore.firestore()

    func logEvent(type: String, payload: [AnyHashable: Any] = [:], extra: [String: Any] = [:]) async {
        let uid = Auth.auth().currentUser?.uid ?? "unknown"

        var safePayload: [String: Any] = [:]
        for (key, value) in payload {
            safePayload[String(describing: key)] = String(describing: value)
        }

        var data: [String: Any] = [
            "uid": uid,
            "type": type,
            "payload": safePayload,
            "createdAt": FieldValue.serverTimestamp(),
            "deviceName": UIDevice.current.name,
            "systemVersion": UIDevice.current.systemVersion
        ]

        for (key, value) in extra {
            data[key] = value
        }

        do {
            try await db.collection("notificationDebugLogs").addDocument(data: data)
            print("📝 Debug log saved:", type)
        } catch {
            print("❌ Failed to save notification debug log:", error)
        }
    }
}

