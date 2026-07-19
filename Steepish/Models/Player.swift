//
//  Player.swift
//  Steepish
//

import Foundation
import FirebaseFirestore

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
/// Firestore: players/{uid}
struct Player: Identifiable, Codable {

    @DocumentID var id: String?

    var name: String
    var characterType: CharacterType
    var lastUpdated: Date
    var createdAt: Date

    // MARK: - Init

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

