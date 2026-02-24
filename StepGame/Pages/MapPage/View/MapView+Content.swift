//
//  MapView+Content.swift
//  StepGame
//

import SwiftUI

extension MapView {

    // MARK: - Content

    var mapContent: some View {
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

    func mapOverlay(size: CGSize) -> some View {
        ZStack {
            ForEach(Array(vm.milestones.enumerated()), id: \.offset) { index, value in
                FlagMarker(number: value, reached: vm.isFlagReached(value))
                    .position(vm.flagPosition(index: index, mapSize: size))
            }

            ForEach(vm.mapPlayers) { p in
                MapPlayerMarker(
                    mapSprite: p.mapSprite,
                    name: p.name,
                    steps: p.steps,
                    isMe: p.isMe,
                    isGroup: vm.isGroupChallenge,
                    place: p.place,
                    attackedByName: p.attackedByName,
                    isUnderSabotage: p.isUnderSabotage,
                    sabotageExpiresAt: p.sabotageExpiresAt,
                    isAttackedByMe: p.isAttackedByMe,
                    lastSyncedAt: p.lastSyncedAt,
                    isChallengeEnded: vm.isChallengeEnded
                )
                .position(vm.positionForPlayer(p, mapSize: size))
                .animation(.easeInOut(duration: 0.35), value: p.progress)
            }
        }
    }

    var hudLayer: some View {
        MapHUDLayer(
            title: vm.titleText,
            isGroup: vm.isGroupChallenge,
            avatars: vm.hudAvatars,
            myAvatar: vm.myHudAvatar,
            durationText: vm.durationText,
            goalSteps: vm.goalSteps,
            stepsLeftText: vm.stepsLeftText,
            daysLeftText: vm.daysLeftText,
            isChallengeEnded: vm.isChallengeEnded,
            onTapMyAvatar: {
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showProfile = true
                }
            }
        )
    }

    // MARK: - Puzzle Result Popup

    @ViewBuilder
    var puzzleResultOverlay: some View {
        if let res = puzzleResult {
            PuzzleResultPopup(
                result: res,
                onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        puzzleResult = nil
                    }
                    showChallengesSheet()
                }
            )
            .environmentObject(session)
            .transition(.opacity)
            .zIndex(5000)
        }
    }

    // MARK: - Result Popup

    @ViewBuilder
    var resultPopup: some View {
        if vm.isShowingResultPopup, let popupVM = vm.resultPopupVM {
            ChallengeResultPopup(
                isPresented: Binding(
                    get: { vm.isShowingResultPopup },
                    set: { newValue in
                        if !newValue {
                            vm.dismissResultPopup()
                            showChallengesSheet()
                        }
                    }
                ),
                vm: popupVM
            )
            .transition(.opacity)
            .zIndex(1000)
        }
    }

    // MARK: - Map Popups

    @ViewBuilder
   var mapPopupLayer: some View {

        if connectivity.isOnline,
           let popup = activeMapPopup {

            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()

                switch popup {
                case .soloLate:
                    SoloLatePopupView(
                        onClose: {
                            recordDismiss(for: .soloLate)
                            activeMapPopup = nil
                            showChallengesSheet()
                        },
                        onConfirm: startSoloGameSafely
                    )

                case .groupAttacker:
                    GroupAttackPopupView(
                        onClose: {
                            recordDismiss(for: .groupAttacker)
                            activeMapPopup = nil
                            showChallengesSheet()
                        },
                        onConfirm: startAttackerGameSafely
                    )

                case .groupDefender:
                    GroupDefensePopupView(
                        onClose: {
                            recordDismiss(for: .groupDefender)
                            activeMapPopup = nil
                            showChallengesSheet()
                        },
                        onConfirm: startDefenderGameSafely
                    )
                }
            }
            .zIndex(3000)
        }
    }
}

// MARK: - Components

private struct MapHUDLayer: View {
    var title: String
    var isGroup: Bool
    var avatars: [String]
    var myAvatar: String
    var durationText: String
    var goalSteps: Int
    var stepsLeftText: String
    var daysLeftText: String
    var isChallengeEnded: Bool
    var onTapMyAvatar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 185)
                .cornerRadius(20)
                .foregroundStyle(Color.light1.opacity(0.5))
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        MapTopHUD(
                            title: title,
                            durationText: durationText,
                            goalSteps: goalSteps,
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

// MARK: - Player Marker
private struct MapPlayerMarker: View {
    let mapSprite: String
    let name: String
    let steps: Int
    let isMe: Bool
    let isGroup: Bool
    let place: Int?
    let attackedByName: String?
    let isUnderSabotage: Bool
    let sabotageExpiresAt: Date?
    let isAttackedByMe: Bool
    let lastSyncedAt: Date?
    let isChallengeEnded: Bool
    
    @State private var showBubble = false
    @State private var showInfoIcon = true
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            
            // Show either bubble OR name badge
            if showBubble {
                PlayerInfoBubble(
                    name: name,
                    steps: steps,
                    isMe: isMe,
                    isGroup: isGroup,
                    place: place,
                    attackedByName: attackedByName,
                    isUnderSabotage: isUnderSabotage,
                    sabotageExpiresAt: sabotageExpiresAt,
                    isAttackedByMe: isAttackedByMe,
                    lastSyncedAt: lastSyncedAt,
                    isChallengeEnded: isChallengeEnded
                )
                .fixedSize()
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showBubble = false
                    }
                }
            } else {
                VStack(spacing: 4) {
                    // Player name button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showBubble.toggle()
                        }
                    } label: {
                        // Name and Place
                        HStack(spacing: 6) {
                            Text(isMe ? "Me" : name)
                                .font(.custom("RussoOne-Regular", size: 12))
                                .foregroundStyle(.light1)

                            if isGroup, let place, (1...3).contains(place) {
                                Image(placeAssetName(place))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                            
                            if showInfoIcon {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.light1)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.light3)
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showInfoIcon = false
                            }
                        }
                    }
                    
                    // Timer badge if under attack
                    if isUnderSabotage, let expires = sabotageExpiresAt {
                        Text(timeRemainingString(until: expires))
                            .font(.custom("RussoOne-Regular", size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                    }
                }
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Character sprite
            Image(mapSprite)
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
        }
        .offset(dragOffset)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragOffset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
        )
        .onChange(of: showBubble) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { showBubble = false }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeRemainingString(until date: Date) -> String {
        let remaining = Int(date.timeIntervalSince(Date()))
        if remaining <= 0 { return "0m" }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m"
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
    // MARK: - Helper Functions
    
    private func timeRemainingString(until date: Date) -> String {
        let remaining = Int(date.timeIntervalSince(Date()))
        if remaining <= 0 { return "0m" }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m"
    }
    
    private func placeAssetName(_ place: Int) -> String {
        switch place {
        case 1: return "Place1"
        case 2: return "Place2"
        case 3: return "Place3"
        default: return "Place1"
        }
    
}


// MARK: - Player Info Bubble

private struct PlayerInfoBubble: View {
    let name: String
    let steps: Int
    let isMe: Bool
    let isGroup: Bool
    let place: Int?
    let attackedByName: String?
    let isUnderSabotage: Bool
    let sabotageExpiresAt: Date?
    let isAttackedByMe: Bool
    let lastSyncedAt: Date?
    let isChallengeEnded: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            // Name and Place
            HStack(spacing: 4) {
                Text(isMe ? "Me" : name)
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(.light1)

                if isGroup, let place, (1...3).contains(place) {
                    Image(placeAssetName(place))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
            
           
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundStyle(.light1)
                
                Text("\(steps.formatted()) Steps")
                    .font(.custom("RussoOne-Regular", size: 12))
                    .foregroundStyle(.light1)
            }
            
            // Last Sync
            if !isChallengeEnded {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 11))
                        .bold()
                        .foregroundStyle(.light2)
                       
                    
                    Text(formatSyncDate(lastSyncedAt))
                        .font(.custom("RussoOne-Regular", size: 10))
                        .foregroundStyle(.light2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
            }
            
            // Sabotage Info
            if isUnderSabotage, let attackedByName, let expires = sabotageExpiresAt {
                Divider()
                    .background(Color.red.opacity(0.3))
                
                VStack(spacing: 6) {
                    Text("⚔️ Under Attack")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(.red)
                    
                    Text(isAttackedByMe ? "Attacked by you!" : "By \(attackedByName)")
                        .font(.custom("RussoOne-Regular", size: 10))
                        .foregroundStyle(.red)
                    
                }
            }
        }
        .padding(12)
        .frame(minWidth: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }
    
    private func formatSyncDate(_ date: Date?) -> String {
        guard let date else { return "Not synced" }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func timeRemainingString(until date: Date) -> String {
        let remaining = Int(date.timeIntervalSince(Date()))
        if remaining <= 0 { return "0m" }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
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

private struct FlagMarker: View {
    let number: Int
    let reached: Bool

    var body: some View {
        ZStack {
            Image(reached ? "Flag2" : "Flag1")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Text("\(number)")
                .font(.custom("RussoOne-Regular", size: 10))
                .foregroundStyle(.light1)
                .strikethrough(reached, color: .light1)
                .padding(.bottom, 25)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - HUD Components
private struct MapTopHUD: View {
    var title: String
    var durationText: String
    var goalSteps: Int
    var isGroup: Bool
    var avatars: [String]
    var myAvatar: String
    var onTapMyAvatar: () -> Void

    var body: some View {
        
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                
                VStack (alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.custom("RussoOne-Regular", size: 28))
                        .foregroundStyle(.white)

                    Text("Goal: \(goalSteps.formatted()) steps in \(durationText)")
                        .font(.custom("RussoOne-Regular", size: 14))
                        .foregroundStyle(.white)
                }
              
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

private struct PlayerAvatar: View {
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

private struct InfoPill: View {
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

private struct ProfileAvatarButton: View {
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


#Preview("MapPlayerMarker - Not Synced Yet") {
    ZStack {
        Color.light2.ignoresSafeArea()

        MapPlayerMarker(
            mapSprite: "character2_normal",
            name: "Noura",
            steps: 100000,
            isMe: false,
            isGroup: true,
            place: nil,
            attackedByName: nil,
            isUnderSabotage: false,
            sabotageExpiresAt: nil,
            isAttackedByMe: false,
            lastSyncedAt: nil,
            isChallengeEnded: false
        )
        .padding()
    }
}

#Preview("MapPlayerMarker - Under Attack") {
    ZStack {
         Image("Map")

        MapPlayerMarker(
            mapSprite: "character1_lazy",
            name: "Noura",
            steps: 5400,
            isMe: false,
            isGroup: true,
            place: 1,
            attackedByName: "Arwa",
            isUnderSabotage: true,
            sabotageExpiresAt: Date().addingTimeInterval(60 * 60 * 2),
            isAttackedByMe: false,
            lastSyncedAt: Date().addingTimeInterval(-60 * 5),
            isChallengeEnded: false
        )
        .padding()
    }
}
