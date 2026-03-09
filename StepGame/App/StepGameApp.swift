//
//  StepGameApp.swift
//  StepGame
//
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    
    static var healthKitManager: HealthKitManager?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        FirebaseApp.configure()
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        return true
    }
    
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
import Foundation
import Network
import Combine

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
