//
//  Models.swift
//  StepGame
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Enums
enum ChallengeMode: String, Codable {
    case solo
    case social
}

enum ChallengeStatus: String, Codable {
    case waiting
    case active
    case ended
}

enum PuzzleMode: String, Codable {
    case attack
    case defense
}

enum CharacterType: String, Codable, CaseIterable {
    case character1, character2, character3

    /// Image key for a specific character state
    func imageKey(state: CharacterState) -> String {
        "\(rawValue)_\(state.rawValue)"
    }
}

extension CharacterType {

    /// Default normal image key
    func normalKey() -> String {
        switch self {
        case .character1: return "character1_normal"
        case .character2: return "character2_normal"
        case .character3: return "character3_normal"
        }
    }
}

enum CharacterState: String, Codable, CaseIterable {
    case active
    case normal
    case lazy
}





// MARK: - Avatar Helper
extension CharacterType {

    func avatarKey() -> String {
        "\(rawValue)_avatar"
    }
}





// MARK: - Player
struct Player: Identifiable, Codable {

    @DocumentID var id: String?

    var name: String

    var totalChallenges: Int
    var completedChallenges: Int
    var totalSteps: Int

    var characterType: CharacterType

    var lastUpdated: Date
    var createdAt: Date

    init(
        id: String? = nil,
        name: String,
        totalChallenges: Int = 0,
        completedChallenges: Int = 0,
        totalSteps: Int = 0,
        characterType: CharacterType = .character1,
        lastUpdated: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.totalChallenges = totalChallenges
        self.completedChallenges = completedChallenges
        self.totalSteps = totalSteps
        self.characterType = characterType
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
    }
}





// MARK: - Challenge
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
    var startedAt: Date? = nil

    /// Result fields
    var winnerId: String? = nil
    var winnerFinishedAt: Date? = nil

    /// End date including any extension
    var effectiveEndDate: Date {
        endDate.addingTimeInterval(TimeInterval(extensionSeconds))
    }

    /// Dynamic mode resolution
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
struct ChallengeParticipant: Identifiable, Codable {

    @DocumentID var id: String?

    var challengeId: String
    var playerId: String

    var steps: Int
    var progress: Double
    var characterState: CharacterState

    var lastUpdated: Date
    var createdAt: Date

    /// Sabotage (existing / keep)
    var sabotageState: CharacterState?
    var sabotageExpiresAt: Date?
    var sabotageByPlayerId: String?


    /// Attack metadata (to compare with defense time)
    var sabotageAttackTimeSeconds: Double?
    var sabotageAppliedAt: Date?
    var groupAttackSucceededAt: Date?
    /// Result tracking per participant
    var finishedAt: Date? = nil
    var place: Int? = nil
    var didShowResultPopup: Bool? = nil

    var lastSyncedAt: Date?
    
    var soloAttemptedAt: Date?
    var groupAttackAttemptedAt: Date?
    var groupDefenseAttemptedAt: Date?

    var soloDismissedAt: Date?
    var groupAttackDismissedAt: Date?
    var groupDefenseDismissedAt: Date?
    
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

        soloPuzzleFailedAt: Date? = nil,
        groupAttackPuzzleFailedAt: Date? = nil,

        sabotageAttackTimeSeconds: Double? = nil,
        sabotageAppliedAt: Date? = nil,
        groupAttackSucceededAt: Date? = nil,
        finishedAt: Date? = nil,
        place: Int? = nil,
        didShowResultPopup: Bool? = nil,
        lastSyncedAt: Date? = nil,
        soloAttemptedAt: Date?  = nil,
        groupAttackAttemptedAt: Date?  = nil,
        groupDefenseAttemptedAt: Date?  = nil,

        soloDismissedAt: Date? = nil,
        groupAttackDismissedAt: Date? = nil,
        groupDefenseDismissedAt: Date? = nil
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
        self.groupAttackSucceededAt = groupAttackSucceededAt

        self.finishedAt = finishedAt
        self.place = place
        self.didShowResultPopup = didShowResultPopup
        self.lastSyncedAt = lastSyncedAt
        self.soloAttemptedAt = soloAttemptedAt
        self.groupAttackAttemptedAt = groupAttackAttemptedAt
        self.groupDefenseAttemptedAt = groupDefenseAttemptedAt

        self.soloDismissedAt = soloDismissedAt
        self.groupAttackDismissedAt = groupAttackDismissedAt
        self.groupDefenseDismissedAt = groupDefenseDismissedAt
    }

    /// Effective character state considering sabotage
    func effectiveState(now: Date = Date()) -> CharacterState {
        if let s = sabotageState,
           let exp = sabotageExpiresAt,
           now < exp { return s }
        return characterState
    }

    var hasShownResultPopup: Bool {
        didShowResultPopup ?? false
    }
}
