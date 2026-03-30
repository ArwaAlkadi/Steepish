//
//  StepGameApp.swift
//  StepGame
//
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import Foundation
import Network
import Combine

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    static var healthKitManager: HealthKitManager?
    
    // MARK: - Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        FirebaseApp.configure()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // MARK: - APNs Registration
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let apnsToken = tokenParts.joined()
        print("✅ APNs Token:", apnsToken)
        Messaging.messaging().apnsToken = deviceToken
        Task {
            await NotificationDebugService.shared.logEvent(
                type: "apns_token_registered",
                extra: ["apnsToken": apnsToken]
            )
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications:", error)
    }
    
    // MARK: - FCM Token
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("❌ FCM token is nil")
            return
        }
        print("✅ FCM Token from MessagingDelegate:", token)
        Task {
            await NotificationService.shared.saveToken(token)
            await NotificationDebugService.shared.logEvent(
                type: "fcm_token_received",
                extra: ["fcmToken": token]
            )
        }
    }
    
    // MARK: - Remote Notification (Silent + Visible)
    // MARK: - Remote Notification (Silent + Visible)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isSilentPush = (userInfo["aps"] as? [String: Any])?["content-available"] as? Int == 1

        if isSilentPush {
            print("🤫 Silent push received")
            Task {
                await NotificationDebugService.shared.logEvent(
                    type: "silent_push_received",
                    payload: userInfo
                )
                let success = await syncStepsInBackground()
                await NotificationDebugService.shared.logEvent(
                    type: success ? "silent_sync_success" : "silent_sync_failed"
                )
                completionHandler(success ? .newData : .noData)
            }
        } else {
            print("🔔 Visible push received")
            completionHandler(.noData)
        }
    }
    
    // MARK: - Notification Tap → Navigate to Challenge
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let challengeId = userInfo["challengeId"] as? String, !challengeId.isEmpty {
            print("🔔 Notification tapped — navigate to challenge:", challengeId)
            NotificationCenter.default.post(
                name: .navigateToChallenge,
                object: nil,
                userInfo: ["challengeId": challengeId]
            )
        }
        completionHandler()
    }
    
    // MARK: - Show notification when app is open
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Background Fetch
    
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
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            await syncStepsInBackground()
        }
    }
    
    // MARK: - Background Sync
    
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
                .whereField("participants", arrayContains: uid)
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

// MARK: - Notification Name
extension Notification.Name {
    static let navigateToChallenge = Notification.Name("navigateToChallenge")
}

// MARK: - Main App

@main
struct StepGameApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var session = GameSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var connectivity = ConnectivityMonitor()

    init() {}

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(health)
                .environmentObject(connectivity)
                .onAppear {
                    AppDelegate.healthKitManager = health
                }
        }
    }
}


// MARK: - ConnectivityMonitor

@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
