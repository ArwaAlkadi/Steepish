//
//  EnterNameViewModel.swift
//  StepGame
//
//

import Foundation
import SwiftUI
import Combine

// MARK: - Enter Name ViewModel
@MainActor
final class EnterNameViewModel: ObservableObject {

    @Published var name: String = ""

    let maxNameCount: Int = 15

    /// Determines if the Start button should be enabled
    var isStartEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Enforces maximum allowed character count
    func enforceNameLimit(_ newValue: String) {
        if newValue.count > maxNameCount {
            name = String(newValue.prefix(maxNameCount))
        }
    }
}
