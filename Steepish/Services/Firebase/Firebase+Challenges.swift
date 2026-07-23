//
//  Firebase+Challenges.swift
//  Steepish
//

import Foundation
import FirebaseFirestore

// MARK: - Challenges

extension FirebaseService {

    // MARK: - Create / Join

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

        // puzzleHistory is written as an empty map so Firestore dot-notation
        // updates (e.g. "puzzleHistory.soloAttemptedAt") always land inside a
        // nested object instead of becoming flat string-keyed fields.
        var partData = try Firestore.Encoder().encode(part)
        partData["puzzleHistory"] = [String: Any]()

        try await db.collection("challenges")
            .document(ref.documentID)
            .collection("participants")
            .document(hostUid)
            .setData(partData)

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

                // puzzleHistory initialized as empty map so dot-notation writes
                // always create nested fields, not flat string keys.
                tx.setData([
                    "challengeId": challengeId,
                    "playerId": uid,
                    "steps": 0,
                    "progress": 0,
                    "characterState": CharacterState.normal.rawValue,
                    "lastUpdated": Timestamp(date: now),
                    "createdAt": Timestamp(date: now),
                    "didShowResultPopup": false,
                    "puzzleHistory": [String: Any]()
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

    // MARK: - Lifecycle

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
}
