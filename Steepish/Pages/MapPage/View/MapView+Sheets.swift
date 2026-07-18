//
//  MapView+Sheets.swift
//  StepGame
//

import SwiftUI

extension MapView {

    // MARK: - Sheets

    func makeChallengesSheet() -> some View {
        ChallengesSheet(
            onTapCreate: {
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showSetupPage = true
                }
            },
            onTapJoin: {
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showJoinPopup = true
                }
            },
            onTapChallenge: { ch in
                session.selectChallenge(ch)
                selectedDetent = .height(90)
                activeSheet = .challenges
            }
        )
        .environmentObject(session)
        .presentationDetents([.height(90), .medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(true)
    }

    func makeJoinPopup() -> some View {
        JoinCodePopup(
            isPresented: $showJoinPopup,
            onJoin: { code in
                await session.joinWithCode(code)
                if let msg = session.errorMessage, !msg.isEmpty { return msg }
                return nil
            }
        )
    }

    func makeSetupView() -> some View {
        SetupChallengeView(
            isPresented: $showSetupPage,
            onDismissWithoutCreating: {
                showChallengesSheet()
            }
        )
        .environmentObject(session)
    }

    func makeProfileView() -> some View {
        NavigationStack {
            ProfileView()
                .environmentObject(session)
        }
    }
}
