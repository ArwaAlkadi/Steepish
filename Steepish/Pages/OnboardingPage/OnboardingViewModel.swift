//
//  OnboardingViewModel.swift
//  Steepish
//

import SwiftUI
import Combine

// MARK: - Onboarding ViewModel

/// Tracks the current page of the onboarding walkthrough.
final class OnboardingViewModel: ObservableObject {

    @Published var currentPage: Int = 0
    let totalPages: Int = 4

    /// Advances to the next page, if not already on the last one.
    func next() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    /// Jumps directly to the last page.
    func skip() {
        currentPage = totalPages - 1
    }
}

