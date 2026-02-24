//
//  PuzzleResultPopup.swift
//  StepGame
//

import SwiftUI

struct PuzzleResultPopup: View {
    let result: PuzzleResult
    let onClose: () -> Void

    @EnvironmentObject private var session: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            card
                .padding(.horizontal, 26)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 16) {
            headerRow

            VStack(spacing: 10) {
                Text(result.title)
                    .font(.custom("RussoOne-Regular", size: 28))
                    .foregroundStyle(.light1)
                    .multilineTextAlignment(.center)

                characterPreview
                    .padding()

                Text(result.message)
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(.light1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                if let opp = result.opponentTime, result.context == .groupDefense {
                    VStack(spacing: 6) {
                        Text("Your time: \(fmt(result.myTime))")
                        Text("Opponent time: \(fmt(opp))")
                    }
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(.light1)
                    .padding(.top, 6)
                }
            }
            .padding(.bottom, 6)
        }
        .padding(18)
        .padding(.bottom, 25)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.light3)
        )
    }

    private var headerRow: some View {
        HStack {
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.light1)
            }
            .buttonStyle(.plain)
        }
    }

    private var characterPreview: some View {
        Image(characterImageName)
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            .accessibilityLabel("Character")
    }

    // MARK: - Helpers

    private var characterImageName: String {
        let type = session.player?.characterType ?? .character1
        let base = type.rawValue
        let suffix = result.success ? "win" : "lose"
        return "\(base)_\(suffix)"
    }

    private func fmt(_ t: Double) -> String {
        String(format: "%.2fs", t)
    }
}

// MARK: - Preview

#Preview("PuzzleResultSheet") {
    // Dummy session for preview
    let session = GameSession()
    return PuzzleResultPopup(
        result: PuzzleResult(
            context: .groupDefense,
            success: true,
            myTime: 1.23,
            opponentTime: 1.88,
            reason: .solved,
            title: "Awesome!",
            message: "You solved the puzzle"
        ),
        onClose: {}
    )
    .environmentObject(session)
}
