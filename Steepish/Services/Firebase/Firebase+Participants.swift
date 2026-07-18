//
//  Firebase+Participants.swift
//  StepGame
//

import Foundation
import FirebaseFirestore

extension FirebaseService {

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
}
