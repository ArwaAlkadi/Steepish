//
//  Models.swift
//  StepGame
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Player
// Firestore: players/{uid}

/// The character skin a player has selected.
enum CharacterType: String, Codable, CaseIterable {
    case character1, character2, character3

    /// Returns the asset name for this character in a given state.
    func imageKey(state: CharacterState) -> String {
        "\(rawValue)_\(state.rawValue)"
    }

    /// Returns the asset name for this character in the normal state.
    func normalKey() -> String {
        "\(rawValue)_normal"
    }

    /// Returns the asset name for the avatar version of this character.
    func avatarKey() -> String {
        "\(rawValue)_avatar"
    }
}

/// The visual and behavioral state of a player's character.
enum CharacterState: String, Codable, CaseIterable {
    case active
    case normal
    case lazy
    case win
}

/// Represents a registered player in the app.
struct Player: Identifiable, Codable {

    @DocumentID var id: String?

    var name: String
    var characterType: CharacterType
    var lastUpdated: Date
    var createdAt: Date

    init(
        id: String? = nil,
        name: String,
        characterType: CharacterType = .character1,
        lastUpdated: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.characterType = characterType
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
    }
}

// MARK: - Challenge
// Firestore: challenges/{challengeId}

/// The mode a challenge was created in.
enum ChallengeMode: String, Codable {
    case solo
    case social
}

/// The current lifecycle state of a challenge.
enum ChallengeStatus: String, Codable {
    case waiting
    case active
    case ended
}

/// Represents a step challenge, either solo or group.
struct Challenge: Identifiable, Codable {

    @DocumentID var id: String?

    var name: String
    var joinCode: String
    var mode: ChallengeMode
    var originalMode: ChallengeMode
    var goalSteps: Int
    var durationDays: Int
    var status: ChallengeStatus
    var createdBy: String
    var playerIds: [String]
    var startDate: Date
    var endDate: Date
    var extensionSeconds: Int
    var createdAt: Date
    var startedAt: Date?
    var winnerId: String?
    var winnerFinishedAt: Date?

    // MARK: - Computed

    /// End date including any time extension from puzzle rewards.
    var effectiveEndDate: Date {
        endDate.addingTimeInterval(TimeInterval(max(0, extensionSeconds)))
    }

    /// Resolves to solo if a social challenge ends up with only one player.
    var currentMode: ChallengeMode {
        if originalMode == .social && playerIds.count == 1 { return .solo }
        return mode
    }

    var maxPlayers: Int { originalMode == .solo ? 1 : 4 }
    var isFull: Bool { playerIds.count >= maxPlayers }

    func canJoin() -> Bool {
        !isFull && (status == .active || status == .waiting)
    }

    init(
        id: String? = nil,
        name: String,
        joinCode: String,
        mode: ChallengeMode,
        originalMode: ChallengeMode? = nil,
        goalSteps: Int,
        durationDays: Int,
        status: ChallengeStatus = .waiting,
        createdBy: String,
        playerIds: [String] = [],
        startDate: Date = Date(),
        endDate: Date,
        extensionSeconds: Int = 0,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        winnerId: String? = nil,
        winnerFinishedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.joinCode = joinCode
        self.mode = mode
        self.originalMode = originalMode ?? mode
        self.goalSteps = goalSteps
        self.durationDays = durationDays
        self.status = status
        self.createdBy = createdBy
        self.playerIds = playerIds
        self.startDate = startDate
        self.endDate = endDate
        self.extensionSeconds = extensionSeconds
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.winnerId = winnerId
        self.winnerFinishedAt = winnerFinishedAt
    }
}

// MARK: - ChallengeParticipant
// Firestore: challenges/{challengeId}/participants/{uid}

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

/// Represents a single player's state within a challenge.
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

    func effectiveState(now: Date = Date()) -> CharacterState {
        if let s = sabotageState,
           let exp = sabotageExpiresAt,
           now < exp {
            return s
        }
        return characterState
    }

    var hasShownResultPopup: Bool {
        didShowResultPopup ?? false
    }

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

