//
//  Challenge.swift
//  StepGame
//

import Foundation
import FirebaseFirestore

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
/// Firestore: challenges/{challengeId}
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
