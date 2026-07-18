//
//   SetupChallengeViewModel.swift
//  StepGame
//

import Foundation
import SwiftUI
import Combine

// MARK: - Setup Challenge ViewModel
@MainActor
final class SetupChallengeViewModel: ObservableObject {

    // MARK: - Inputs
    @Published var challengeName: String = ""
    
    // NEW: Date picker instead of fixed periods
    @Published var startDate: Date = Date()
    @Published var endDate: Date = {
        Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    }()
    
    @Published var hasSelectedEndDate: Bool = false
    
    @Published var steps: Double = 10000
    @Published var mode: ModeOption = .solo

    // MARK: - Validation
    let maxNameCount: Int = 15
    @Published var errorMessage: String? = nil

    /// Challenge creation outcome
    enum Outcome {
        case soloCreated
        case groupCreated
        case failed
    }

    /// Enforces maximum challenge name length
    func clampName() {
        if challengeName.count > maxNameCount {
            challengeName = String(challengeName.prefix(maxNameCount))
        }
    }
    
    /// Calculate duration in days from selected date range
    /// This function returns the duration WITHOUT changing the models
    private func calculateDuration() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return max(components.day ?? 1, 1) // At least 1 day
    }

    // MARK: - Create Challenge
    func createChallenge(session: UserSession) async -> Outcome {
        errorMessage = nil

        let trimmed = challengeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a challenge name."
            return .failed
        }
        
        // Validate dates
        guard endDate > startDate else {
            errorMessage = "End date must be after start date."
            return .failed
        }

        let goalSteps = max(Int(steps), 1)
        let durationDays = calculateDuration() // Calculate from dates
        let challengeMode: ChallengeMode = (mode == .group) ? .social : .solo

        // Call existing GameSession function - NO CHANGES to it
        await session.createNewChallenge(
            name: trimmed,
            mode: challengeMode,
            goalSteps: goalSteps,
            durationDays: durationDays
        )

        /// Check session-level error
        if let msg = session.errorMessage, !msg.isEmpty {
            errorMessage = msg
            return .failed
        }

        guard let created = session.challenge else {
            errorMessage = "Failed to create challenge. Please try again."
            return .failed
        }

        if created.originalMode == .social {
            return .groupCreated
        } else {
            return .soloCreated
        }
    }
}

// MARK: - Mode Option
enum ModeOption: Equatable {
    case solo, group
}
