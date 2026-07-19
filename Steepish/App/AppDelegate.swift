//
//  AppDelegate.swift
//  Steepish
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

// MARK: - App Delegate

/// Handles app lifecycle events, push notification registration, and background step syncing.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    static var healthKitManager: HealthKitManager?

    // MARK: - Launch

    /// Configures Firebase, enables background fetch, and wires up notification delegates on launch.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    // MARK: - APNs Registration

    /// Forwards the device's APNs token to Firebase Messaging.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let apnsToken = tokenParts.joined()
        print("APNs Token:", apnsToken)
        Messaging.messaging().apnsToken = deviceToken
    }

    /// Logs a failure to register for remote notifications.
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications:", error)
    }

    // MARK: - FCM Token

    /// Persists the FCM token whenever Firebase issues a new one.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("FCM token is nil")
            return
        }
        print("FCM Token:", token)
        Task {
            await FirebaseService.shared.saveFCMToken(token)
        }
    }

    // MARK: - Remote Notification (Silent + Visible)

    /// Handles incoming remote notifications. Silent pushes trigger a background step sync
    /// and are logged to Firestore so their outcome can be tracked.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isSilentPush = (userInfo["aps"] as? [String: Any])?["content-available"] as? Int == 1

        if isSilentPush {
            print("Silent push received")
            Task {
                await FirebaseService.shared.logNotificationEvent(
                    type: "silent_push_received",
                    payload: userInfo
                )
                let success = await syncStepsInBackground()
                await FirebaseService.shared.logNotificationEvent(
                    type: success ? "silent_sync_success" : "silent_sync_failed"
                )
                completionHandler(success ? .newData : .noData)
            }
        } else {
            print("Visible push received")
            completionHandler(.noData)
        }
    }

    // MARK: - Notification Tap → Navigate to Challenge

    /// Posts a navigation notification when the user taps a push notification tied to a challenge.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let challengeId = userInfo["challengeId"] as? String, !challengeId.isEmpty {
            print("Notification tapped — navigate to challenge:", challengeId)
            NotificationCenter.default.post(
                name: .navigateToChallenge,
                object: nil,
                userInfo: ["challengeId": challengeId]
            )
        }
        completionHandler()
    }

    // MARK: - Show notification when app is open

    /// Displays a banner with sound for notifications received while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Background Fetch

    /// Triggers a background step sync during the system's periodic background fetch window.
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundFetch")
        Task {
            let success = await syncStepsInBackground()
            completionHandler(success ? .newData : .noData)
        }
    }

    /// Re-syncs steps whenever the app returns to the foreground.
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            await syncStepsInBackground()
        }
    }

    // MARK: - Background Sync

    /// Fetches the user's active challenge, pulls the latest step count from HealthKit, and
    /// writes it to Firestore. Sync status/diagnostics are cached to `UserDefaults`.
    private func syncStepsInBackground() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            UserDefaults.standard.set(false, forKey: "lastSyncSuccess")
            UserDefaults.standard.set("No user logged in", forKey: "lastSyncError")
            return false
        }
        guard let healthKit = Self.healthKitManager, healthKit.isAuthorized else {
            UserDefaults.standard.set(false, forKey: "lastSyncSuccess")
            UserDefaults.standard.set("HealthKit not authorized", forKey: "lastSyncError")
            return false
        }
        do {
            let db = Firestore.firestore()
            let challengeSnapshot = try await db
                .collection("challenges")
                .whereField("playerIds", arrayContains: uid)
                .whereField("status", isEqualTo: "active")
                .limit(to: 1)
                .getDocuments()
            guard let challengeDoc = challengeSnapshot.documents.first else {
                UserDefaults.standard.set(false, forKey: "lastSyncSuccess")
                UserDefaults.standard.set("No active challenge", forKey: "lastSyncError")
                return false
            }
            let challengeId = challengeDoc.documentID
            let challengeData = challengeDoc.data()
            guard let startTimestamp = challengeData["startDate"] as? Timestamp else {
                UserDefaults.standard.set(false, forKey: "lastSyncSuccess")
                UserDefaults.standard.set("No start date", forKey: "lastSyncError")
                return false
            }
            let startDate = startTimestamp.dateValue()
            let steps = try await healthKit.fetchSteps(from: startDate, to: Date())
            try await db
                .collection("challenges")
                .document(challengeId)
                .collection("participants")
                .document(uid)
                .setData([
                    "steps": steps,
                    "lastSyncedAt": FieldValue.serverTimestamp()
                ], merge: true)
            UserDefaults.standard.set(true, forKey: "lastSyncSuccess")
            UserDefaults.standard.set(Date(), forKey: "lastSyncTime")
            UserDefaults.standard.removeObject(forKey: "lastSyncError")
            return true
        } catch {
            UserDefaults.standard.set(false, forKey: "lastSyncSuccess")
            UserDefaults.standard.set(error.localizedDescription, forKey: "lastSyncError")
            return false
        }
    }
}

