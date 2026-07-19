//
//  ChallengeParticipant.swift
//  Steepish
//

import Foundation
import FirebaseFirestore

/// Represents a single player's state within a challenge.
/// Firestore: challenges/{challengeId}/participants/{uid}
struct ChallengeParticipant: Identifiable, Codable {

    @DocumentID var id: String?

    var challengeId: String
    var playerId: String
    var steps: Int
    var progress: Double
    var characterState: CharacterState
    var lastUpdated: Date
    var createdAt: Date

    // MARK: - Sabotage
    var sabotageState: CharacterState?
    var sabotageExpiresAt: Date?
    var sabotageByPlayerId: String?
    var sabotageAttackTimeSeconds: Double?
    var sabotageAppliedAt: Date?

    // MARK: - Result
    var finishedAt: Date?
    var place: Int?
    var didShowResultPopup: Bool?
    var lastSyncedAt: Date?

    // MARK: - Left Challenge
    var leftAt: Date?
    var leftAtSteps: Int?

    // MARK: - Puzzle History
    /// All puzzle-related timestamps grouped in a single nested object.
    var puzzleHistory: PuzzleHistory?

    // MARK: - Computed

    /// The character state to display, factoring in any active sabotage effect.
    func effectiveState(now: Date = Date()) -> CharacterState {
        if let s = sabotageState,
           let exp = sabotageExpiresAt,
           now < exp {
            return s
        }
        return characterState
    }

    /// Whether the result popup has already been shown for this participant.
    var hasShownResultPopup: Bool {
        didShowResultPopup ?? false
    }

    // MARK: - Init

    init(
        id: String? = nil,
        challengeId: String,
        playerId: String,
        steps: Int = 0,
        progress: Double = 0.0,
        characterState: CharacterState = .normal,
        lastUpdated: Date = Date(),
        createdAt: Date = Date(),
        sabotageState: CharacterState? = nil,
        sabotageExpiresAt: Date? = nil,
        sabotageByPlayerId: String? = nil,
        sabotageAttackTimeSeconds: Double? = nil,
        sabotageAppliedAt: Date? = nil,
        finishedAt: Date? = nil,
        place: Int? = nil,
        didShowResultPopup: Bool? = nil,
        lastSyncedAt: Date? = nil,
        leftAt: Date? = nil,
        leftAtSteps: Int? = nil,
        puzzleHistory: PuzzleHistory? = nil
    ) {
        self.id = id
        self.challengeId = challengeId
        self.playerId = playerId
        self.steps = steps
        self.progress = progress
        self.characterState = characterState
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
        self.sabotageState = sabotageState
        self.sabotageExpiresAt = sabotageExpiresAt
        self.sabotageByPlayerId = sabotageByPlayerId
        self.sabotageAttackTimeSeconds = sabotageAttackTimeSeconds
        self.sabotageAppliedAt = sabotageAppliedAt
        self.finishedAt = finishedAt
        self.place = place
        self.didShowResultPopup = didShowResultPopup
        self.lastSyncedAt = lastSyncedAt
        self.leftAt = leftAt
        self.leftAtSteps = leftAtSteps
        self.puzzleHistory = puzzleHistory
    }
}

