// MARK: - ViewModel

import SwiftUI
import Combine

final class OnboardingViewModel: ObservableObject {

    @Published var currentPage: Int = 0
    let totalPages: Int = 4

    func next() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    func skip() {
        currentPage = totalPages - 1
    }
}

