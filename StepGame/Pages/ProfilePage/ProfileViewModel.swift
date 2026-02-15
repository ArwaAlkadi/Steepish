//
//  ProfileViewModel.swift
//  StepGame
//

import Foundation
import SwiftUI
import Combine

// MARK: - Profile ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var isEditing: Bool = false
    @Published var isSaving: Bool = false

    @Published var draftName: String = ""
    @Published var selectedCharacter: CharacterType = .character1

    @Published var showError: Bool = false
    @Published var errorMessage: String? = nil

    private var originalName: String = ""
    private var originalCharacter: CharacterType = .character1
    
    let allCharacters: [CharacterType] = [.character1, .character2, .character3]

    var displayName: String {
        draftName.isEmpty ? "Player" : draftName
    }

    var currentCharacterKey: String {
        selectedCharacter.normalKey()
    }

    var currentAvatarKey: String {
        selectedCharacter.avatarKey()
    }

    var selectedIndex: Int {
        allCharacters.firstIndex(where: { $0 == selectedCharacter }) ?? 0
    }

    // MARK: - Load
    func loadFromSession(_ player: Player?) {
        guard let player else { return }

        draftName = player.name
        selectedCharacter = player.characterType

        originalName = player.name
        originalCharacter = player.characterType
    }

    // MARK: - Edit Mode
    func enterEdit() {
        isEditing = true
        showError = false
        errorMessage = nil
    }

    func exitEdit() {
        isEditing = false
        showError = false
        errorMessage = nil
    }

    // MARK: - Validation
    func validateDraft() -> Bool {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your name."
            showError = true
            return false
        }
        draftName = trimmed
        return true
    }

    // MARK: - HasChanges

    var hasChanges: Bool {
        draftName != originalName ||
        selectedCharacter != originalCharacter
    }

    // MARK: - Save
    func save(session: GameSession, currentPlayer: Player) async {
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
