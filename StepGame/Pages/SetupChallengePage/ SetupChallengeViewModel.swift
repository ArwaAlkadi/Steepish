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
    @Published var selectedPeriod: PeriodOption = .threeDays
    @Published var steps: Double = 5000
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

    // MARK: - Create Challenge
    func createChallenge(session: GameSession) async -> Outcome {
        errorMessage = nil

        let trimmed = challengeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a challenge name."
            return .failed
        }

        let goalSteps = max(Int(steps), 1)
        let durationDays = selectedPeriod.days
        let challengeMode: ChallengeMode = (mode == .group) ? .social : .solo

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

// MARK: - Period Option

enum PeriodOption: CaseIterable, Equatable {
    case threeDays, week, month

    var title: String {
        switch self {
        case .threeDays: return "3 Days"
        case .week: return "Week"
        case .month: return "Month"
        }
    }

    var days: Int {
        switch self {
        case .threeDays: return 3
        case .week: return 7
        case .month: return 30
        }
    }
}

// MARK: - Mode Option

enum ModeOption: Equatable {
    case solo, group
}
