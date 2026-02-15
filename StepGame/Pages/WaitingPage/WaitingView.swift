//
//  WaitingView.swift
//  StepGame
//
//

import SwiftUI
import Combine

struct WaitingRoomView: View {

    @EnvironmentObject private var connectivity: ConnectivityMonitor
    @EnvironmentObject private var session: GameSession
    @StateObject private var vm = WaitingRoomViewModel()

    @State private var showLeaveAlert = false
    @State private var showShareSheet = false
    @State private var didCopy = false

    @State private var showOfflineBanner: Bool = true
    
    var body: some View {
        ZStack {
            Color.light3.ignoresSafeArea()

            VStack(spacing: 18) {

                // MARK: - Leave / Close
                HStack {
                    Spacer()
                    Button {
                        showLeaveAlert = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.light1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)

                Text(vm.titleText)
                    .font(.custom("RussoOne-Regular", size: 34))
                    .foregroundStyle(Color.light1)

                StepsPill(text: vm.goalStepsText)

                // MARK: - Join Code Actions
                HStack(spacing: 14) {

                    JoinCodePill(
                        code: vm.joinCodeText,
                        didCopy: didCopy
                    ) {
                        UIPasteboard.general.string = vm.joinCodeText
                        withAnimation { didCopy = true }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { didCopy = false }
                        }
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.light1)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.85)))
                    }
                }

                Text(vm.playerCountText)
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(Color.light1.opacity(0.9))
                    .padding(.top, -6)
                
                Spacer(minLength: 10)

                LobbyCenter(players: vm.lobbyPlayers)

                Spacer()

                if vm.isHost {
                    Button {
                        Task { await vm.startChallenge() }
                    } label: {
                        Text(vm.isStarting ? "Starting..." : "Start!")
                            .font(.custom("RussoOne-Regular", size: 18))
                            .foregroundStyle(Color.light3)
                            .frame(width: 220, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color.light1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isStarting || !vm.canStart)
                    .opacity((vm.isStarting || !vm.canStart) ? 0.6 : 1)
                    .padding(.bottom, 18)
                } else {
                    Text(vm.footerTextForPlayer)
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(Color.light1)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 22)
                }
            }
            .padding(.horizontal, 20)
            
            if !connectivity.isOnline {
                OfflineBanner(isVisible: $showOfflineBanner)
            }
            
        }
        .navigationBarBackButtonHidden(true)

        // MARK: - Share Sheet
        .sheet(isPresented: $showShareSheet) {
            ActivityView(
                activityItems: [
                    "🔥 Steepish Challenge!\n\n🎟 Code: \(vm.joinCodeText)\n\nJoin the challenge — think you can beat me? 🏆"
                ]
            )
        }

        // MARK: - Leave Confirmation
        .alert("Leave Challenge?", isPresented: $showLeaveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await vm.leaveOrDeleteChallenge() }
            }
        } message: {
            Text("Are you sure you want to leave? The challenge will be cancelled if you're the host.")
        }

        .onAppear {
            vm.bind(session: session)
        }

        .onDisappear {
            vm.unbind()
            Task { await session.handleExitWaitingRoomIfStillWaiting() }
        }
    }
}

// MARK: - UI Parts

private struct StepsPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.custom("RussoOne-Regular", size: 14))
                .foregroundStyle(.white)

            Image(systemName: "shoeprints.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.light2))
    }
}

private struct JoinCodePill: View {
    let code: String
    let didCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(code)
                .font(.custom("RussoOne-Regular", size: 18))
                .foregroundStyle(Color.light1)

            Button(action: onCopy) {
                Group {
                    if didCopy {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.light1)
                    } else {
                        Image("CopyIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: 180, height: 44)
        .background(Capsule().fill(Color.white.opacity(0.85)))
    }
}

private struct LobbyCenter: View {
    let players: [LobbyPlayer]

    var body: some View {
        ZStack {
            Image("Tent")
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 210)
                .opacity(0.55)

            let slots = slotPositions()
            let shown = Array(players.prefix(4))

            ForEach(Array(shown.enumerated()), id: \.element.id) { i, p in
                LobbyAvatar(
                    image: p.avatarAsset,
                    name: p.name + (p.isMe ? " (Me)" : "")
                )
                .position(slots[i])
            }
        }
        .frame(height: 360)
    }

    /// Lobby avatar positions
    private func slotPositions() -> [CGPoint] {
        [
            CGPoint(x: 90,  y: 120),
            CGPoint(x: 270, y: 120),
            CGPoint(x: 90,  y: 280),
            CGPoint(x: 270, y: 280)
        ]
    }
}

private struct LobbyAvatar: View {
    let image: String
    let name: String

    var body: some View {
        VStack(spacing: 10) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .background(Circle().fill(Color.light4.opacity(0.7)))

            Text(name)
                .font(.custom("RussoOne-Regular", size: 18))
                .foregroundStyle(Color.light1)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
