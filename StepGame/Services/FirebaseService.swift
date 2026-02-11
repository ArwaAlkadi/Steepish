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

    // MARK: - Auth (Anonymous)
    func signInIfNeeded() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    // MARK: - Players
    func createOrUpdatePlayer(
        uid: String,
        name: String,
        characterType: CharacterType = .character1
    ) async throws -> Player {

        let ref = db.collection("players").document(uid)
        let now = Date()

        let data: [String: Any] = [
            "name": name,
            "totalChallenges": 0,
            "completedChallenges": 0,
            "totalSteps": 0,
            "characterType": characterType.rawValue,
            "lastUpdated": Timestamp(date: now),
            "createdAt": Timestamp(date: now)
        ]

        try await ref.setData(data, merge: true)
        return try await fetchPlayer(uid: uid)
    }

    func fetchPlayer(uid: String) async throws -> Player {
        let doc = try await db.collection("players").document(uid).getDocument()
        guard let player = try? doc.data(as: Player.self) else {
            throw NSError(
                domain: "Player",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Player not found"]
            )
        }
        return player
    }

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

            let players: [Player] = snap.documents.compactMap { try? $0.data(as: Player.self) }
            result.append(contentsOf: players)

            i = end
        }

        return result
    }

    // MARK: - Challenges
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

        // MARK: - Place Counter Seed (Stored In Firestore)
        try await ref.setData([
            "nextPlace": 1
        ], merge: true)

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

    func joinChallenge(by joinCode: String, uid: String) async throws -> Challenge {

        let q = try await db.collection("challenges")
            .whereField("joinCode", isEqualTo: joinCode)
            .limit(to: 1)
            .getDocuments()

        guard let doc = q.documents.first else {
            throw NSError(domain: "Join", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid code"])
        }

        var ch = try doc.data(as: Challenge.self)
        guard let challengeId = ch.id else {
            throw NSError(domain: "Join", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing challenge id"])
        }

        if ch.playerIds.contains(uid) { return ch }

        if ch.playerIds.count >= ch.maxPlayers {
            throw NSError(domain: "Join", code: 409, userInfo: [NSLocalizedDescriptionKey: "Challenge is full"])
        }

        var newIds = ch.playerIds
        newIds.append(uid)

        try await db.collection("challenges").document(challengeId).updateData([
            "playerIds": newIds
        ])

        let part = ChallengeParticipant(
            challengeId: challengeId,
            playerId: uid,
            steps: 0,
            progress: 0,
            characterState: .normal,
            lastUpdated: Date(),
            createdAt: Date(),
            finishedAt: nil,
            place: nil,
            didShowResultPopup: false
        )

        try await db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .document(uid)
            .setData(from: part)

        let updatedDoc = try await db.collection("challenges").document(challengeId).getDocument()
        return try updatedDoc.data(as: Challenge.self)
    }

    // MARK: - Start Social Challenge (Host)
    func startChallenge(challengeId: String, hostUid: String) async throws {
        try await db.collection("challenges")
            .document(challengeId)
            .updateData([
                "status": ChallengeStatus.active.rawValue,
                "startedAt": Timestamp(date: Date())
            ])
    }

    // MARK: - Participant Updates (Steps)
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

        // MARK: - Participant Progress Update
        try await ref.setData([
            "challengeId": challengeId,
            "playerId": uid,
            "steps": steps,
            "progress": progress,
            "characterState": characterState.rawValue,
            "lastUpdated": Timestamp(date: now)
        ], merge: true)
    }

    // MARK: - Results (Atomic finish + place + winner)
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

                // MARK: - Mark Participant Finished
                tx.setData([
                    "finishedAt": Timestamp(date: now),
                    "place": assignedPlace,
                    "lastUpdated": Timestamp(date: now)
                ], forDocument: pRef, merge: true)

                // MARK: - Increment Place Counter
                tx.setData([
                    "nextPlace": assignedPlace + 1
                ], forDocument: chRef, merge: true)

                // MARK: - Claim Winner If Needed
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

    // MARK: - Mark Challenge Ended
    func markChallengeEnded(challengeId: String, now: Date = Date()) async throws {
        try await db.collection("challenges")
            .document(challengeId)
            .updateData([
                "status": ChallengeStatus.ended.rawValue,
                "endedAt": Timestamp(date: now)
            ])
    }

    // MARK: - Realtime Listeners
    func listenMyChallenges(uid: String, onChange: @escaping ([Challenge]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .whereField("playerIds", arrayContains: uid)
            .addSnapshotListener { snap, _ in
                let docs = snap?.documents ?? []
                let list: [Challenge] = docs.compactMap { try? $0.data(as: Challenge.self) }
                onChange(list.sorted { $0.createdAt > $1.createdAt })
            }
    }

    func listenChallenge(challengeId: String, onChange: @escaping (Challenge?) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .addSnapshotListener { snap, _ in
                guard let snap else { onChange(nil); return }
                let model = try? snap.data(as: Challenge.self)
                onChange(model)
            }
    }

    func listenParticipants(challengeId: String, onChange: @escaping ([ChallengeParticipant]) -> Void) -> ListenerRegistration {
        db.collection("challenges")
            .document(challengeId)
            .collection("participants")
            .addSnapshotListener { snap, _ in
                let docs = snap?.documents ?? []
                let list: [ChallengeParticipant] = docs.compactMap { try? $0.data(as: ChallengeParticipant.self) }
                onChange(list)
            }
    }

    // MARK: - Delete Challenge (Host)
    func deleteChallenge(challengeId: String) async throws {
        let chRef = db.collection("challenges").document(challengeId)

        let partsSnap = try await chRef.collection("participants").getDocuments()

        let batch = db.batch()
        for d in partsSnap.documents {
            batch.deleteDocument(d.reference)
        }
        batch.deleteDocument(chRef)

        try await batch.commit()
    }

    // MARK: - Player Profile
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

    // MARK: - Leave Challenge (Player)
    func leaveChallenge(challengeId: String, uid: String) async throws {
        let ref = db.collection("challenges").document(challengeId)

        try await ref.updateData([
            "playerIds": FieldValue.arrayRemove([uid])
        ])

        try await ref.collection("participants").document(uid).delete()
    }

    // MARK: - Helpers
    static func generateJoinCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }

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
}
