//
//  StartViewModel.swift
//  StepGame
//

import Foundation
import Combine
import SwiftUI

// MARK: - Start ViewModel
@MainActor
final class StartViewModel: ObservableObject {

    @Published var showJoinPopup: Bool = false

    /// Builds greeting text using player name with fallback
    func greetingText(playerName: String?) -> String {
        let name = (playerName?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Player"
        return "Hi, \(name)!"
    }

    /// Static subtitle text
    func subtitleText() -> String {
        "Move more. Go stronger."
    }

    /// Returns avatar image name with fallback
    func avatarImageName(characterType: CharacterType?) -> String {
        let type = characterType ?? .character1
        return type.imageKey(state: .normal)
    }

    /// Controls button interaction state
    func isInteractionEnabled(isLoading: Bool, isHealthAuthorized: Bool) -> Bool {
        !isLoading && isHealthAuthorized
    }
}
