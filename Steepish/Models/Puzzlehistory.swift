//
//  PuzzleHistory.swift
//  Steepish
//

import Foundation

/// The context in which a puzzle is triggered.
enum PuzzleMode: String, Codable {
    case attack
    case defense
}

/// Groups all puzzle-related timestamps for a participant into a single nested object.
/// Stored as a nested map in Firestore under the key "puzzleHistory".
struct PuzzleHistory: Codable {

    // MARK: - Attempts
    var soloAttemptedAt: Date?
    var groupAttackAttemptedAt: Date?
    var groupDefenseAttemptedAt: Date?

    // MARK: - Dismissals
    var soloDismissedAt: Date?
    var groupAttackDismissedAt: Date?
    var groupDefenseDismissedAt: Date?

    // MARK: - Outcomes
    var soloPuzzleFailedAt: Date?
    var groupAttackPuzzleFailedAt: Date?
    var groupAttackSucceededAt: Date?

    // MARK: - Init

    init(
        soloAttemptedAt: Date? = nil,
        groupAttackAttemptedAt: Date? = nil,
        groupDefenseAttemptedAt: Date? = nil,
        soloDismissedAt: Date? = nil,
        groupAttackDismissedAt: Date? = nil,
        groupDefenseDismissedAt: Date? = nil,
        soloPuzzleFailedAt: Date? = nil,
        groupAttackPuzzleFailedAt: Date? = nil,
        groupAttackSucceededAt: Date? = nil
    ) {
        self.soloAttemptedAt = soloAttemptedAt
        self.groupAttackAttemptedAt = groupAttackAttemptedAt
        self.groupDefenseAttemptedAt = groupDefenseAttemptedAt
        self.soloDismissedAt = soloDismissedAt
        self.groupAttackDismissedAt = groupAttackDismissedAt
        self.groupDefenseDismissedAt = groupDefenseDismissedAt
        self.soloPuzzleFailedAt = soloPuzzleFailedAt
        self.groupAttackPuzzleFailedAt = groupAttackPuzzleFailedAt
        self.groupAttackSucceededAt = groupAttackSucceededAt
    }
}

