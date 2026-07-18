//
//  Firebase+Puzzle.swift
//  StepGame
//

import Foundation
import FirebaseFirestore

extension FirebaseService {

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

        try await ref.setData([kind.attemptedField: Timestamp(date: Date())], merge: true)
    }

    /// Records when a player dismisses a puzzle without completing it.
    func markPuzzleDismissed(challengeId: String, uid: String, kind: PuzzleAttemptKind) async throws {
        let ref = db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)

        try await ref.setData([kind.dismissedField: Timestamp(date: Date())], merge: true)
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
}
