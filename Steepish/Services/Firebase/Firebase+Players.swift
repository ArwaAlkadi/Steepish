//
//  Firebase+Players.swift
//  Steepish
//

import Foundation
import FirebaseFirestore

// MARK: - Players

extension FirebaseService {

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
}

