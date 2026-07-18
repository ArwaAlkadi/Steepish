//
//  PuzzlePromptPopup.swift
//  StepGame
//

import SwiftUI

// MARK: - Solo Late Popup

struct SoloLatePopupView: View {
    var onClose: () -> Void
    var onConfirm: () -> Void

    @State private var isConfirmSelected: Bool = true

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.light1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 14) {
                Text("You're Falling Behind")
                    .font(.custom("RussoOne-Regular", size: 20))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)

                Text("Solve this puzzle to get +1 extra day")
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            HStack(spacing: 12) {
                PopupChipButton(
                    title: "No",
                    isSelected: !isConfirmSelected
                ) {
                    isConfirmSelected = false
                    onClose()
                }

                PopupChipButton(
                    title: "Yes",
                    isSelected: isConfirmSelected
                ) {
                    isConfirmSelected = true
                    onConfirm()
                }
            }
            .padding(.vertical)
        }
        .padding(18)
        .frame(maxWidth: 350)
        .frame(height: 340)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(Color.light3)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Group Attack Popup

struct GroupAttackPopupView: View {
    var targetPlayerName: String
    var onClose: () -> Void
    var onConfirm: () -> Void

    @State private var isConfirmSelected: Bool = true

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.light1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 14) {
                Text("Take Your Chance")
                    .font(.custom("RussoOne-Regular", size: 20))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)

                Text("Win this puzzle to sabotage \(targetPlayerName)'s character for 3 hours")
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            HStack(spacing: 12) {
                PopupChipButton(
                    title: "No",
                    isSelected: !isConfirmSelected
                ) {
                    isConfirmSelected = false
                    onClose()
                }

                PopupChipButton(
                    title: "Attack",
                    isSelected: isConfirmSelected
                ) {
                    isConfirmSelected = true
                    onConfirm()
                }
            }
            .padding(.vertical)
        }
        .padding(18)
        .frame(maxWidth: 350)
        .frame(height: 340)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(Color.light3)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Group Defense Popup

struct GroupDefensePopupView: View {
    var onClose: () -> Void
    var onConfirm: () -> Void

    @State private var isConfirmSelected: Bool = true

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.light1)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 14) {
                Text("Defend Your Progress")
                    .font(.custom("RussoOne-Regular", size: 20))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)

                Text("Solve the puzzle to remove the sabotage. Want to try?")
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            HStack(spacing: 12) {
                PopupChipButton(
                    title: "Later",
                    isSelected: !isConfirmSelected
                ) {
                    isConfirmSelected = false
                    onClose()
                }

                PopupChipButton(
                    title: "Defend",
                    isSelected: isConfirmSelected
                ) {
                    isConfirmSelected = true
                    onConfirm()
                }
            }
            .padding(.vertical)
        }
        .padding(18)
        .frame(maxWidth: 350)
        .frame(height: 340)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(Color.light3)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Components

private struct PopupChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("RussoOne-Regular", size: 14))
                .foregroundStyle(isSelected ? Color.white : Color.light1)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.light1 : Color.white)
                        .overlay(
                            Capsule().stroke(Color.light4.opacity(0.35), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("PuzzlePromptViews") {
    ZStack {
        Color.black.opacity(0.4).ignoresSafeArea()
        GroupDefensePopupView(onClose: {}, onConfirm: {})
            .padding()
    }
}
