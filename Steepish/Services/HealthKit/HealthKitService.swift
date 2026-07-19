//
//  HealthKitService.swift
//  Steepish
//

import HealthKit
import SwiftUI
import Combine

// MARK: - HealthKit Manager

/// Requests HealthKit authorization and reads step counts for background and on-demand syncing.
@MainActor
final class HealthKitManager: ObservableObject {

    @Published var isAuthorized: Bool = false

    private let healthStore = HKHealthStore()
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    // MARK: - Authorization

    /// Requests read access to step count data and refreshes the authorization state.
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

            // Wait for system dialog
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshAuthorizationState()

        } catch {
            print("Authorization failed: \(error)")
            isAuthorized = false
        }
    }

    /// Re-checks authorization by attempting an actual read, since HealthKit's reported
    /// status can't always be trusted.
    func refreshAuthorizationState() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            print("HealthKit not available on this device")
            return
        }

        print("Testing HealthKit by attempting to read steps...")

        // Don't trust status - just try to read
        let canRead = await testReadAuthorization()
        isAuthorized = canRead

        print("Final isAuthorized: \(isAuthorized)")
    }

    /// Attempts to read the last 7 days of step data to infer whether read access is granted.
    private func testReadAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in

            // Try to read steps from last 7 days (more likely to have data)
            let now = Date()
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

            let predicate = HKQuery.predicateForSamples(
                withStart: sevenDaysAgo,
                end: now,
                options: .strictStartDate
            )

            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in

                // Check for errors
                if let hkError = error as? HKError {
                    let errorCode = hkError.code.rawValue
                    print("HKError code: \(errorCode)")

                    // Code 4 = Authorization Denied
                    // Code 5 = Authorization Not Determined
                    // Code 11 = No data (but authorized!)

                    if errorCode == 4 {  // errorAuthorizationDenied
                        print("Authorization explicitly denied")
                        continuation.resume(returning: false)
                        return
                    }

                    if errorCode == 5 {  // errorAuthorizationNotDetermined
                        print("Authorization not determined")
                        continuation.resume(returning: false)
                        return
                    }

                    if errorCode == 11 {  // No data available
                        print("No data, but authorized to read")
                        continuation.resume(returning: true)
                        return
                    }

                    // Any other error - assume authorized
                    print("Error code \(errorCode): \(hkError.localizedDescription)")
                    continuation.resume(returning: true)
                    return
                }

                // No error - success!
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                print("Successfully read \(Int(steps)) steps from last 7 days")
                continuation.resume(returning: true)
            }

            healthStore.execute(query)
        }
    }

    /// Alternate authorization probe reading today's steps. Currently unused but kept
    /// for parity with `testReadAuthorization`.
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

                // Check for authorization errors specifically
                if let error = error as? HKError {
                    if error.code == .errorAuthorizationDenied {
                        print("HealthKit: Authorization denied")
                        continuation.resume(returning: false)
                        return
                    }

                    if error.code == .errorAuthorizationNotDetermined {
                        print("HealthKit: Authorization not determined")
                        continuation.resume(returning: false)
                        return
                    }
                }

                // "No data available" is NOT an authorization error!
                // It just means no steps recorded yet today
                if let error = error {
                    print("HealthKit read error: \(error.localizedDescription)")
                    // If it's just "no data", we're still authorized
                    if error.localizedDescription.contains("No data available") {
                        print("No data, but authorized")
                        continuation.resume(returning: true)
                        return
                    }
                    continuation.resume(returning: false)
                    return
                }

                // Successfully read data (even if 0 steps)
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                print("HealthKit: Read successful - \(Int(steps)) steps")
                continuation.resume(returning: true)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Settings

    /// Opens the system Settings app so the user can change HealthKit permissions.
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Step Queries

    /// Fetches the total step count between two dates.
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

    /// Fetches the step count for today so far.
    func getTodaySteps() async throws -> Int {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        return try await fetchSteps(from: startOfDay, to: now)
    }
}

