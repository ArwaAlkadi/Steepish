//
//  MapView.swift
//  StepGame
//

import SwiftUI
import UIKit

struct MapView: View {

    @EnvironmentObject private var session: GameSession
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var connectivity: ConnectivityMonitor

    @StateObject private var vm = MapViewModel()

    @State private var selectedDetent: PresentationDetent = .height(90)

    @State private var showJoinPopup = false
    @State private var reopenChallengesSheetAfterJoinDismiss = false

    @State private var showSetupPage = false

    @State private var showProfile = false
    @State private var reopenChallengesSheetAfterProfileDismiss = false
    @State private var showOfflineBanner = true

   
    // MARK: - Single Sheet (Challenges only)
    private enum ActiveSheet: Identifiable {
        case challenges
        var id: Int { 1 }
    }

    @State private var activeSheet: ActiveSheet? = .challenges

    var body: some View {
        ZStack {
            Color.light2.ignoresSafeArea()

            mapContent
            hudLayer
            resultPopup
            
            if !connectivity.isOnline {
                OfflineBanner(isVisible: $showOfflineBanner)
                       }
        }
        .sheet(item: $activeSheet) { _ in
            makeChallengesSheet()
        }
        .fullScreenCover(isPresented: $showJoinPopup, onDismiss: onJoinDismiss) {
            makeJoinPopup()
        }
        .fullScreenCover(isPresented: $showSetupPage) {
            makeSetupView()
        }
        .fullScreenCover(isPresented: $showProfile, onDismiss: onProfileDismiss) {
            makeProfileView()
        }
        .onAppear {
            selectedDetent = .height(90)
            activeSheet = .challenges
            vm.bind(session: session)
            vm.startStepsSync(health: health)
        }
        .onDisappear {
            vm.stopStepsSync()
            vm.unbind()
        }
        .onChange(of: session.challenge?.id) { _, _ in
            vm.bind(session: session)
            vm.startStepsSync(health: health)
        }
        .onChange(of: session.player?.name) { _, _ in
            vm.bind(session: session)
        }
        .onChange(of: session.player?.characterType) { _, _ in
            vm.bind(session: session)
        }
    }

    // MARK: - Subviews
    private var mapContent: some View {
        ScrollView(showsIndicators: false) {
            Image("Map")
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { geo in
                        ZStack {
                            mapOverlay(size: geo.size)
                            WindTumbleweedView(mapSize: geo.size)
                        }
                    }
                }
        }
        .contentMargins(0, for: .scrollContent)
        .ignoresSafeArea()
    }

    private func mapOverlay(size: CGSize) -> some View {
        Group {
            ForEach(Array(vm.milestones.enumerated()), id: \.offset) { index, value in
                FlagMarker(
                    number: value,
                    reached: vm.isFlagReached(value)
                )
                .position(vm.flagPosition(index: index, mapSize: size))
            }

            ForEach(vm.mapPlayers) { p in
                MapPlayerMarker(
                    mapSprite: p.mapSprite,
                    name: p.name,
                    steps: p.steps,
                    isMe: p.isMe,
                    isGroup: vm.isGroupChallenge,
                    place: p.place
                )
                .position(vm.positionForPlayer(p, mapSize: size))
                .animation(.easeInOut(duration: 0.35), value: p.progress)
            }
        }
    }

    private var hudLayer: some View {
        MapHUDLayer(
            title: vm.titleText,
            isGroup: vm.isGroupChallenge,
            avatars: vm.hudAvatars,
            myAvatar: vm.myHudAvatar,
            stepsLeftText: vm.stepsLeftText,
            daysLeftText: vm.daysLeftText,
            isChallengeEnded: vm.isChallengeEnded, // ✅
            onTapMyAvatar: {
                reopenChallengesSheetAfterProfileDismiss = true
                selectedDetent = .height(90)
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showProfile = true
                }
            }
        )
    }

    @ViewBuilder
    private var resultPopup: some View {
        if vm.isShowingResultPopup, let popupVM = vm.resultPopupVM {
            ChallengeResultPopup(
                isPresented: Binding(
                    get: { vm.isShowingResultPopup },
                    set: { newValue in
                        if !newValue { vm.dismissResultPopup() }
                    }
                ),
                vm: popupVM
            )
            .transition(.opacity)
            .zIndex(1000)
        }
    }

    // MARK: - Challenges Sheet
    private func makeChallengesSheet() -> some View {
        ChallengesSheet(
            onTapCreate: {
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showSetupPage = true
                }
            },
            onTapJoin: {
                reopenChallengesSheetAfterJoinDismiss = true
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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

    // MARK: - Other Views
    private func makeJoinPopup() -> some View {
        JoinCodePopup(
            isPresented: $showJoinPopup,
            onJoin: { code in
                await session.joinWithCode(code)
                if let msg = session.errorMessage, !msg.isEmpty { return msg }
                reopenChallengesSheetAfterJoinDismiss = false
                return nil
            }
        )
    }

    private func makeSetupView() -> some View {
        SetupChallengeView(
            isPresented: $showSetupPage,
            onDismissWithoutCreating: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedDetent = .height(90)
                    activeSheet = .challenges
                }
            }
        )
        .environmentObject(session)
    }

    private func makeProfileView() -> some View {
        NavigationStack {
            ProfileView()
                .environmentObject(session)
        }
    }

    // MARK: - Handlers
    private func onJoinDismiss() {
        if reopenChallengesSheetAfterJoinDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                selectedDetent = .height(90)
                activeSheet = .challenges
            }
        }
        reopenChallengesSheetAfterJoinDismiss = false
    }

    private func onProfileDismiss() {
        selectedDetent = .height(90)
        if reopenChallengesSheetAfterProfileDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                activeSheet = .challenges
            }
        }
        reopenChallengesSheetAfterProfileDismiss = false
    }
}

// MARK: - HUD Layer

private struct MapHUDLayer: View {
    var title: String
    var isGroup: Bool
    var avatars: [String]
    var myAvatar: String
    var stepsLeftText: String
    var daysLeftText: String
    var isChallengeEnded: Bool

    var onTapMyAvatar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 155)
                .cornerRadius(20)
                .foregroundStyle(Color.light1.opacity(0.3))
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        MapTopHUD(
                            title: title,
                            isGroup: isGroup,
                            avatars: avatars,
                            myAvatar: myAvatar,
                            onTapMyAvatar: onTapMyAvatar
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 50)
                )

            if !isChallengeEnded {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        InfoPill(icon: "shoeprints.fill", text: stepsLeftText)
                        InfoPill(icon: "hourglass", text: daysLeftText)
                    }
                    Spacer()
                }
                .padding()
            }

            Spacer()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Player Marker (On Map)

private struct MapPlayerMarker: View {
    let mapSprite: String
    let name: String
    let steps: Int
    let isMe: Bool

    let isGroup: Bool
    let place: Int?

    var body: some View {
        VStack(spacing: 6) {

            Image(systemName: "bubble.middle.bottom.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
                .foregroundStyle(.white)
                .overlay(alignment: .center) {

                    VStack(spacing: 2) {

                        HStack(spacing: 4) {

                            Text(isMe ? "Me" : name)
                                .font(.custom("RussoOne-Regular", size: 10))
                                .foregroundStyle(.light1)

                            if isGroup, let place,
                               (1...3).contains(place) {

                                Image(placeAssetName(place))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                            }
                        }

                        Text("\(steps.formatted()) Steps")
                            .font(.custom("RussoOne-Regular", size: 8))
                            .foregroundStyle(.light2)
                    }
                    .multilineTextAlignment(.center)
                    .offset(y: -6)
                }

            Image(mapSprite)
                .resizable()
                .scaledToFit()
                .frame(width: 85, height: 85)
        }
    }

    private func placeAssetName(_ place: Int) -> String {
        switch place {
        case 1: return "Place1"
        case 2: return "Place2"
        case 3: return "Place3"
        default: return "Place1"
        }
    }
}

// MARK: - Flag Marker

struct FlagMarker: View {
    let number: Int
    let reached: Bool

    var body: some View {
        ZStack {
            Image(reached ? "Flag1" : "Flag2")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)

            Text("\(number)")
                .font(.custom("RussoOne-Regular", size: 12))
                .foregroundStyle(.light1)
                .padding(.bottom, 25)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - HUD Components

struct MapTopHUD: View {
    var title: String
    var isGroup: Bool
    var avatars: [String]
    var myAvatar: String

    var onTapMyAvatar: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.custom("RussoOne-Regular", size: 28))
                    .foregroundStyle(.white)

                if isGroup {
                    HStack(spacing: -10) {
                        ForEach(Array(avatars.prefix(6).enumerated()), id: \.offset) { _, a in
                            PlayerAvatar(imageName: a)
                        }
                    }
                }
            }

            Spacer()

            ProfileAvatarButton(
                imageName: myAvatar,
                size: 54,
                onTap: onTapMyAvatar
            )
        }
    }
}

struct PlayerAvatar: View {
    var imageName: String
    var size: CGFloat = 44

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(Circle().fill(Color.light4))
            .overlay(Circle().stroke(Color.light1, lineWidth: 3))
    }
}

struct InfoPill: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.light1)

            Text(text)
                .font(.custom("RussoOne-Regular", size: 14))
                .foregroundStyle(Color.light1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.light4))
    }
}

struct ProfileAvatarButton: View {
    var imageName: String
    var size: CGFloat = 54
    var onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .background(Circle().fill(Color.light4))
                .overlay(Circle().stroke(Color.light1, lineWidth: 3))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
