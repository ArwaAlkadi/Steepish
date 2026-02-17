import HealthKit
import SwiftUI
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    
    @Published var isAuthorized: Bool = false
    
    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available")
            isAuthorized = false
            return
        }
        
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: [stepType]
            )
            
            print("Authorization requested")
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshAuthorizationState()
            
        } catch {
            print("Authorization failed: \(error)")
            isAuthorized = false
        }
    }
    
    func refreshAuthorizationState() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            print("HealthKit not available")
            return
        }
        
        let authorized = await canReadSteps()
        isAuthorized = authorized
        
        print("HealthKit authorization check: \(authorized)")
    }
    
    private func canReadSteps() async -> Bool {
        return await withCheckedContinuation { continuation in
            
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: now,
                options: .strictStartDate
            )
            
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                
                if let error = error as? HKError {
                    if error.code == .errorAuthorizationDenied ||
                       error.code == .errorAuthorizationNotDetermined {
                        print("HealthKit: Access denied or not determined")
                        continuation.resume(returning: false)
                        return
                    }
                }
                
                if error != nil {
                    print("HealthKit: Read failed - \(error!.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                print("HealthKit: Read successful - \(Int(steps)) steps")
                continuation.resume(returning: true)
            }
            
            healthStore.execute(query)
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func fetchSteps(from start: Date, to end: Date) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: .strictStartDate
            )
            
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
    
    func getTodaySteps() async throws -> Int {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        return try await fetchSteps(from: startOfDay, to: now)
    }
}
