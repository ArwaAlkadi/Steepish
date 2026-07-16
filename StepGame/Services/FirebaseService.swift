//
//  FirebaseService.swift
//  StepGame
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class FirebaseService {

    static let shared = FirebaseService()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - Auth

    /// Signs in anonymously if no current user exists, returns the UID.
    func signInIfNeeded() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    // MARK: - Players

    /// Creates or updates a player document with name and character type.
    func createOrUpdatePlayer(
        uid: String,
        name: String,
        characterType: CharacterType = .character1
    ) async throws -> Player {

        let ref = db.collection("players").document(uid)
        let now = Date()

        try await ref.setData([
            "name": name,
            "characterType": characterType.rawValue,
            "lastUpdated": Timestamp(date: now),
            "createdAt": Timestamp(date: now)
        ], merge: true)

        return try await fetchPlayer(uid: uid)
    }

    /// Fetches a single player by UID.
    func fetchPlayer(uid: String) async throws -> Player {
        let doc = try await db.collection("players").document(uid).getDocument()
        guard let player = try? doc.data(as: Player.self) else {
            throw NSError(domain: "Player", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Player not found"])
        }
        return player
    }

    /// Fetches multiple players by their UIDs (batched in chunks of 10).
    func fetchPlayers(uids: [String]) async throws -> [Player] {
        let unique = Array(Set(uids)).filter { !$0.isEmpty }
        guard !unique.isEmpty else { return [] }

        var result: [Player] = []
        let chunkSize = 10
        var i = 0

        while i < unique.count {
            let end = min(i + chunkSize, unique.count)
            let chunk = Array(unique[i..<end])

            let snap = try await db.collection("players")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            result.append(contentsOf: snap.documents.compactMap { try? $0.data(as: Player.self) })
            i = end
        }

        return result
    }

    /// Updates a player's display name and character type.
    func updatePlayerProfile(uid: String, name: String, characterType: CharacterType) async throws -> Player {
        let ref = db.collection("players").document(uid)
        let now = Date()

        try await ref.setData([
            "name": name,
            "characterType": characterType.rawValue,
            "lastUpdated": Timestamp(date: now)
        ], merge: true)

        return try await fetchPlayer(uid: uid)
    }

    // MARK: - Challenges

    /// Creates a new challenge and adds the host as the first participant.
    func createChallenge(
        hostUid: String,
        name: String,
        mode: ChallengeMode,
        goalSteps: Int,
        durationDays: Int
    ) async throws -> Challenge {

        let joinCode = Self.generateJoinCode()
        let now = Date()
        let startDay = Calendar.current.startOfDay(for: now)
        let endDay = Calendar.current.date(byAdding: .day, value: durationDays, to: startDay)
            ?? startDay.addingTimeInterval(TimeInterval(durationDays * 86400))

        let isSocial = (mode == .social)
        let status: ChallengeStatus = isSocial ? .waiting : .active
        let startedAt: Date? = isSocial ? nil : now

        var challenge = Challenge(
            name: name,
            joinCode: joinCode,
            mode: mode,
            originalMode: mode,
            goalSteps: goalSteps,
            durationDays: durationDays,
            status: status,
            createdBy: hostUid,
            playerIds: [hostUid],
            startDate: startDay,
            endDate: endDay,
            extensionSeconds: 0,
            createdAt: now,
            startedAt: startedAt,
            winnerId: nil,
            winnerFinishedAt: nil
        )

        let ref = db.collection("challenges").document()
        try ref.setData(from: challenge)
        try await ref.setData(["nextPlace": 1], merge: true)

        var saved = challenge
        saved.id = ref.documentID

        let part = ChallengeParticipant(
            challengeId: ref.documentID,
            playerId: hostUid,
            steps: 0,
            progress: 0,
            characterState: .normal,
            lastUpdated: now,
            createdAt: now,
            finishedAt: nil,
            place: nil,
            didShowResultPopup: false
        )

        try await db.collection("challenges")
            .document(ref.documentID)
            .collection("participants")
            .document(hostUid)
            .setData(from: part)

        return saved
    }

    /// Joins a challenge by its 6-character join code using an atomic transaction.
    func joinChallenge(by joinCode: String, uid: String) async throws -> Challenge {

        let q = try await db.collection("challenges")
            .whereField("joinCode", isEqualTo: joinCode)
            .limit(to: 1)
            .getDocuments()

        guard let doc = q.documents.first else {
            throw NSError(domain: "Join", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid code"])
        }

        let challengeId = doc.documentID
        let chRef = db.collection("challenges").document(challengeId)
        let partRef = chRef.collection("participants").document(uid)

        try await db.runTransaction { tx, errPtr -> Any? in
            do {
                let chSnap = try tx.getDocument(chRef)

                guard chSnap.exists else {
                    throw NSError(domain: "Join", code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "Challenge not found"])
                }

                guard let ch = try? chSnap.data(as: Challenge.self) else {
                    throw NSError(domain: "Join", code: 500,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid challenge data"])
                }

                if ch.playerIds.contains(uid) { return nil }

                if ch.playerIds.count >= ch.maxPlayers {
                    throw NSError(domain: "Join", code: 409,
                                  userInfo: [NSLocalizedDescriptionKey: "Challenge is full"])
                }

                tx.updateData(["playerIds": FieldValue.arrayUnion([uid])], forDocument: chRef)

                let now = Date()
                tx.setData([
                    "challengeId": challengeId,
                    "playerId": uid,
                    "steps": 0,
                    "progress": 0,
                    "characterState": CharacterState.normal.rawValue,
                    "lastUpdated": Timestamp(date: now),
                    "createdAt": Timestamp(date: now),
                    "didShowResultPopup": false
                ], forDocument: partRef, merge: true)

                return nil
            } catch let e {
                errPtr?.pointee = e as NSError
                return nil
            }
        }

        let updatedDoc = try await chRef.getDocument()
        return try updatedDoc.data(as: Challenge.self)
    }

    /// Starts a social challenge (host only).
    func startChallenge(challengeId: String, hostUid: String) async throws {
        try await db.collection("challenges").document(challengeId).updateData([
            "status": ChallengeStatus.active.rawValue,
            "startedAt": Timestamp(date: Date())
        ])
    }

    /// Renames a challenge.
    func renameChallenge(challengeId: String, newName: String) async throws {
        try await db.collection("challenges").document(challengeId).updateData([
            "name": newName
        ])
    }

    /// Deletes a challenge and all its participants.
    func deleteChallenge(challengeId: String) async throws {
        let chRef = db.collection("challenges").document(challengeId)
        let partsSnap = try await chRef.collection("participants").getDocuments()

        let batch = db.batch()
        for d in partsSnap.documents { batch.deleteDocument(d.reference) }
        batch.deleteDocument(chRef)

        try await batch.commit()
    }

    /// Marks a challenge as ended.
    func markChallengeEnded(challengeId: String, now: Date = Date()) async throws {
        try await db.collection("challenges").document(challengeId).updateData([
            "status": ChallengeStatus.ended.rawValue,
            "endedAt": Timestamp(date: now)
        ])
    }

    // MARK: - Participants

    /// Updates a participant's step count, progress, and character state.
    func updateParticipantSteps(
        challengeId: String,
        uid: String,
        steps: Int,
        progress: Double,
        characterState: CharacterState
    ) async throws {

        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)

        let now = Date()
        try await ref.setData([
            "challengeId": challengeId,
            "playerId": uid,
            "steps": steps,
            "progress": progress,
            "characterState": characterState.rawValue,
            "lastSyncedAt": Timestamp(date: now)
        ], merge: true)
    }

    /// Atomically marks a participant as finished and assigns their place.
    /// Also sets the challenge winner if none has been set yet.
    func tryMarkFinishedAndClaimWinnerIfNeeded(
        challengeId: String,
        uid: String,
        now: Date = Date()
    ) async throws {

        let chRef = db.collection("challenges").document(challengeId)
        let pRef = chRef.collection("participants").document(uid)

        try await db.runTransaction { tx, errPtr -> Any? in
            do {
                let chSnap = try tx.getDocument(chRef)
                let pSnap = try tx.getDocument(pRef)

                let winnerId = chSnap.data()?["winnerId"] as? String
                let alreadyFinished = (pSnap.data()?["finishedAt"] as? Timestamp) != nil
                if alreadyFinished { return nil }

                let nextPlace = (chSnap.data()?["nextPlace"] as? Int) ?? 1
                let assignedPlace = nextPlace

                tx.setData([
                    "finishedAt": Timestamp(date: now),
                    "place": assignedPlace,
                    "lastUpdated": Timestamp(date: now)
                ], forDocument: pRef, merge: true)

                tx.setData(["nextPlace": assignedPlace + 1], forDocument: chRef, merge: true)

                if winnerId == nil {
                    tx.setData([
                        "winnerId": uid,
                        "winnerFinishedAt": Timestamp(date: now)
                    ], forDocument: chRef, merge: true)
                }

                return nil
            } catch let e {
                errPtr?.pointee = e as NSError
                return nil
            }
        }
    }

    /// Marks a participant as having left the challenge.
    func leaveChallenge(challengeId: String, uid: String) async throws {
        let ref = db.collection("challenges").document(challengeId)

        let doc = try await ref.getDocument()
        let createdBy = doc.data()?["createdBy"] as? String

        guard createdBy != uid else {
            throw NSError(domain: "Leave", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Host cannot leave. Delete the challenge instead."])
        }

        let now = Date()
        let partRef = ref.collection("participants").document(uid)
        let partDoc = try await partRef.getDocument()
        let currentSteps = partDoc.data()?["steps"] as? Int ?? 0

        try await partRef.setData([
            "leftAt": Timestamp(date: now),
            "leftAtSteps": currentSteps
        ], merge: true)

        try await ref.updateData([
            "playerIds": FieldValue.arrayRemove([uid])
        ])
    }

    // MARK: - Sabotage

    /// Applies a group attack sabotage to a target participant (3-hour duration).
    func applyGroupAttack(
        challengeId: String,
        targetId: String,
        attackerId: String,
        attackTimeSeconds: Double
    ) async throws {

        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(targetId)

        let now = Date()
        let expires = now.addingTimeInterval(3 * 60 * 60)

        try await ref.setData([
            "sabotageState": CharacterState.lazy.rawValue,
            "sabotageExpiresAt": Timestamp(date: expires),
            "sabotageByPlayerId": attackerId,
            "sabotageAttackTimeSeconds": attackTimeSeconds,
            "sabotageAppliedAt": Timestamp(date: now)
        ], merge: true)
    }

    /// Removes an active sabotage from a participant (used when defense puzzle is solved).
    func cancelGroupAttack(challengeId: String, targetId: String) async throws {
        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(targetId)

        try await ref.setData([
            "sabotageState": FieldValue.delete(),
            "sabotageExpiresAt": FieldValue.delete(),
            "sabotageByPlayerId": FieldValue.delete()
        ], merge: true)
    }

    // MARK: - Puzzle History
    // All puzzle timestamps are stored as a nested object under "puzzleHistory"
    // to keep the participant document organized.

    enum PuzzleAttemptKind {
        case solo
        case groupAttack
        case groupDefense

        /// The Firestore key for the attempt timestamp inside puzzleHistory.
        var attemptedField: String {
            switch self {
            case .solo: return "puzzleHistory.soloAttemptedAt"
            case .groupAttack: return "puzzleHistory.groupAttackAttemptedAt"
            case .groupDefense: return "puzzleHistory.groupDefenseAttemptedAt"
            }
        }

        /// The Firestore key for the dismissal timestamp inside puzzleHistory.
        var dismissedField: String {
            switch self {
            case .solo: return "puzzleHistory.soloDismissedAt"
            case .groupAttack: return "puzzleHistory.groupAttackDismissedAt"
            case .groupDefense: return "puzzleHistory.groupDefenseDismissedAt"
            }
        }
    }

    /// Records when a player opens a puzzle.
    func markPuzzleAttempted(challengeId: String, uid: String, kind: PuzzleAttemptKind) async throws {
        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)

        try await ref.setData([
            kind.attemptedField: Timestamp(date: Date())
        ], merge: true)
    }

    /// Records when a player dismisses a puzzle without completing it.
    func markPuzzleDismissed(challengeId: String, uid: String, kind: PuzzleAttemptKind) async throws {
        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)

        try await ref.setData([
            kind.dismissedField: Timestamp(date: Date())
        ], merge: true)
    }

    /// Records when a player fails the solo puzzle.
    func markSoloPuzzleFailed(challengeId: String, uid: String) async throws {
        let ref = db.collection("challenges").document(challengeId)
            .collection("participants").document(uid)

        try await ref.setData([
            "puzzleHistory.soloPuzzleFailedAt": Timestamp(date: Date())
        ], merge: true)
    }

    /// Records when a player fails the group attack puzzle.
    func markGroupAttackPuzzleFailed(challengeId: String, uid: String) async throws {
        let ref = db.collection("challenges").document(challengeId)
            .collection("participants").document(uid)

        try await ref.setData([
            "puzzleHistory.groupAttackPuzzleFailedAt": Timestamp(date: Date())
        ], merge: true)
    }

    /// Records when a player successfully completes the group attack puzzle.
    func markGroupAttackSucceeded(challengeId: String, uid: String) async throws {
        let ref = db.collection("challenges").document(challengeId)
            .collection("participants").document(uid)

        try await ref.setData([
            "puzzleHistory.groupAttackSucceededAt": Timestamp(date: Date())
        ], merge: true)
    }

    // MARK: - Solo Puzzle Reward

    /// Adds a 1-day extension to a challenge (solo puzzle reward).
    func addOneDayExtension(challengeId: String) async throws {
        let ref = db.collection("challenges").document(challengeId)

        try await db.runTransaction { tx, errPtr -> Any? in
            do {
                let snap = try tx.getDocument(ref)
                let current = (snap.data()?["extensionSeconds"] as? Int) ?? 0
                tx.setData(["extensionSeconds": current + 86400], forDocument: ref, merge: true)
                return nil
            } catch let e {
                errPtr?.pointee = e as NSError
                return nil
            }
        }
    }

    // MARK: - Realtime Listeners

    /// Listens to all challenges the player is part of.
    func listenMyChallenges(uid: String, onChange: @escaping ([Challenge]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .whereField("playerIds", arrayContains: uid)
            .addSnapshotListener { snap, _ in
                let list: [Challenge] = (snap?.documents ?? []).compactMap { try? $0.data(as: Challenge.self) }
                onChange(list.sorted { $0.createdAt > $1.createdAt })
            }
    }

    /// Listens to a single challenge document.
    func listenChallenge(challengeId: String, onChange: @escaping (Challenge?) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .addSnapshotListener { snap, _ in
                guard let snap else { onChange(nil); return }
                onChange(try? snap.data(as: Challenge.self))
            }
    }

    /// Listens to all participants in a challenge.
    func listenParticipants(challengeId: String, onChange: @escaping ([ChallengeParticipant]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .addSnapshotListener { snap, _ in
                let list: [ChallengeParticipant] = (snap?.documents ?? []).compactMap { try? $0.data(as: ChallengeParticipant.self) }
                onChange(list)
            }
    }

    /// Listens to a single participant document.
    func listenMyParticipant(
        challengeId: String,
        uid: String,
        onChange: @escaping (ChallengeParticipant?) -> Void
    ) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)
            .addSnapshotListener { snap, _ in
                guard let snap, snap.exists else { onChange(nil); return }
                onChange(try? snap.data(as: ChallengeParticipant.self))
            }
    }

    // MARK: - Helpers

    /// Generates a random 6-character join code.
    static func generateJoinCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }
}

