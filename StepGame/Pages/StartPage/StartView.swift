//
//  StartView.swift
//  StepGame
//


import SwiftUI
import UIKit
import Combine

struct StartView: View {

    @EnvironmentObject var session: GameSession
    @EnvironmentObject var health: HealthKitManager
    @StateObject private var vm = StartViewModel()

    @State private var showSetup = false
    @State private var showProfile = false

    var body: some View {
        ZStack {

            Image("Map2")
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .blur(radius: 3.5)
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 20) {

                ZStack {

                    HStack {
                        Spacer()

                        Button {
                            showProfile = true
                        } label: {
                            Image(session.player?.characterType.avatarKey() ?? "character1_avatar")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .background(
                                    Circle().fill(Color.light4.opacity(0.7))
                                )
                                .overlay(
                                    Circle().stroke(Color.light1.opacity(0.8), lineWidth: 4)
                                )
                                .clipShape(Circle())
                                .padding(30)
                        }
                        .buttonStyle(.plain)
                        .fullScreenCover(isPresented: $showProfile) {
                            NavigationStack {
                                ProfileView()
                                    .environmentObject(session)
                            }
                        }
                    }

                    if !health.isAuthorized {
                        HealthPermissionGate(
                            onAllow: { health.requestAuthorization() },
                            onOpenSettings: { health.openAppSettings() }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 70)
                    }
                }

                Spacer()

                VStack {
                    Text(vm.greetingText(playerName: session.player?.name))
                        .font(.custom("RussoOne-Regular", size: 36))
                        .foregroundStyle(Color.light1)

                    Text(vm.subtitleText())
                        .font(.custom("RussoOne-Regular", size: 24))
                        .foregroundStyle(Color.light1)
                }

                Button {
                    showSetup = true
                } label: {
                    BigButtonLabel(title: "Start new challenge")
                }
                .disabled(!vm.isInteractionEnabled(isLoading: session.isLoading, isHealthAuthorized: health.isAuthorized))
                .opacity(vm.isInteractionEnabled(isLoading: session.isLoading, isHealthAuthorized: health.isAuthorized) ? 1 : 0.5)

                Button {
                    withAnimation(.easeInOut) { vm.showJoinPopup = true }
                } label: {
                    BigButtonLabel(title: "Join with code")
                }
                .disabled(!vm.isInteractionEnabled(isLoading: session.isLoading, isHealthAuthorized: health.isAuthorized))
                .opacity(vm.isInteractionEnabled(isLoading: session.isLoading, isHealthAuthorized: health.isAuthorized) ? 1 : 0.5)
                .padding(.bottom, 70)
            }

            // MARK: - Join Code Popup
            if vm.showJoinPopup {
                JoinCodePopup(
                    isPresented: $vm.showJoinPopup,
                    onJoin: { code in
                        /// Clear any previous error
                        session.clearError()

                        await session.joinWithCode(code)

                            /// Return error message to keep popup open
                        if let msg = session.errorMessage, !msg.isEmpty {
                            return msg
                        }

                        return nil
                    }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupChallengeView(isPresented: $showSetup)
                .environmentObject(session)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await health.refreshAuthorizationState()
                if !health.isAuthorized {
                    await health.requestAuthorization()
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            Task { await health.refreshAuthorizationState() }
        }
    }
}

// MARK: - UI Helpers

private struct BigButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("RussoOne-Regular", size: 20))
            .foregroundColor(.light3)
            .frame(width: 280, height: 55)
            .background(Color("Light1"))
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
    }
}

private struct HealthPermissionGate: View {
    let onAllow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {

            // MARK: - Health Permission Gate
            Text("Steps Access Required")
                .font(.custom("RussoOne-Regular", size: 16))
                .foregroundStyle(Color.light1)

            Text("To play, please allow step access from the Health app settings.")
                .font(.custom("RussoOne-Regular", size: 12))
                .foregroundStyle(Color.light2)
                .multilineTextAlignment(.center)

            Button(action: onOpenSettings) {
                Text("Open Settings")
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(Color.light1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 21).fill(Color.light4.opacity(0.7)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.light3))
    }
}

#Preview("StartView") {
    StartViewPreviewHost()
}

// MARK: - Preview Host
private struct StartViewPreviewHost: View {
    @StateObject private var session = GameSession()
    @StateObject private var health = HealthKitManager()

    var body: some View {
        NavigationStack {
            StartView()
                .environmentObject(session)
                .environmentObject(health)
        }
        .onAppear {
            session.player = Player(
                id: "preview_uid",
                name: "Arwa",
                totalChallenges: 0,
                completedChallenges: 0,
                totalSteps: 0,
                characterType: .character1,
                lastUpdated: Date(),
                createdAt: Date()
            )
            session.playerName = "Arwa"
        }
    }
}
