//
//  ProfileViewModel.swift
//  Steepish
//

import Foundation
import SwiftUI
import Combine

// MARK: - Profile ViewModel

/// Backs `ProfileView`: manages the draft name/character while editing and persists
/// changes back through `UserSession`.
@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var isEditing: Bool = false
    @Published var isSaving: Bool = false

    @Published var draftName: String = ""
    @Published var selectedCharacter: CharacterType = .character1

    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil
    @Published var nameError: String? = nil

    private var originalName: String = ""
    private var originalCharacter: CharacterType = .character1

    let allCharacters: [CharacterType] = [.character1, .character2, .character3]

    /// The name to display, falling back to "Player" when empty.
    var displayName: String {
        draftName.isEmpty ? "Player" : draftName
    }

    /// Asset key for the currently selected character's normal state.
    var currentCharacterKey: String {
        selectedCharacter.normalKey()
    }

    /// Asset key for the currently selected character's avatar.
    var currentAvatarKey: String {
        selectedCharacter.avatarKey()
    }

    /// Index of the selected character within `allCharacters`.
    var selectedIndex: Int {
        allCharacters.firstIndex(where: { $0 == selectedCharacter }) ?? 0
    }

    // MARK: - Load

    /// Seeds the draft state from the session's current player.
    func loadFromSession(_ player: Player?) {
        guard let player else { return }

        draftName = player.name
        selectedCharacter = player.characterType

        originalName = player.name
        originalCharacter = player.characterType
    }

    // MARK: - Edit Mode

    /// Enters editing mode and clears any previous errors.
    func enterEdit() {
        isEditing = true
        showError = false
        errorMessage = nil
        nameError = nil
    }

    /// Exits editing mode and clears any previous errors.
    func exitEdit() {
        isEditing = false
        showError = false
        errorMessage = nil
        nameError = nil
    }

    // MARK: - Validation

    /// Trims and validates the draft name, setting `nameError` if invalid.
    func validateDraft() -> Bool {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameError = "Please enter your name."
            return false
        }
        nameError = nil
        draftName = trimmed
        return true
    }

    // MARK: - HasChanges

    /// Whether the draft name or character differs from what was originally loaded.
    var hasChanges: Bool {
        draftName != originalName ||
        selectedCharacter != originalCharacter
    }

    // MARK: - Save

    /// Validates and persists the draft profile via `UserSession`, exiting edit mode on success.
    func save(session: UserSession, currentPlayer: Player) async {
        guard validateDraft() else { return }

        isSaving = true
        defer { isSaving = false }

        await session.updateProfile(
            name: draftName,
            characterType: selectedCharacter
        )

        if let msg = session.errorMessage, !msg.isEmpty {
            errorMessage = msg
            showError = true
        } else {
            exitEdit()
        }
    }
}

