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
                let pos = vm.positionForPlayer(p, mapSize: size)

                MapPlayerMarker(
                    id: p.id,
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
                    isChallengeEnded: vm.isChallengeEnded,
                    hasLeft: p.hasLeft,
                    leftAt: p.leftAt,
                    goalSteps: vm.goalSteps,
                    onTap: { vm.bringToFront(playerId: p.id) },
                    activePlayerBubbleId: $activePlayerBubbleId
                )
                .offset(y: -10)
                .position(pos)
                .zIndex(vm.zIndexForPlayer(p.id))
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
                        targetPlayerName: vm.leadingPlayerName,
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
    
    let id: String
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
    let hasLeft: Bool
    let leftAt: Date?
    let goalSteps: Int
    let onTap: () -> Void
    
    @Binding var activePlayerBubbleId: String?
    @State private var showInfoIcon = true
    @GestureState private var dragOffset: CGSize = .zero

    private var showBubble: Bool {
           activePlayerBubbleId == id
       }
    
    var body: some View {
        VStack(spacing: 0) {
            
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
                    goalSteps: goalSteps,
                    isChallengeEnded: isChallengeEnded,
                    hasLeft: hasLeft,
                    leftAt: leftAt,
                    stepLengthMeters: 0.75
                )
                .fixedSize()
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        // Show only first 5 characters in badge
                        Text(isMe ? "Me" : truncatedName)
                            .font(.custom("RussoOne-Regular", size: 12))
                            .foregroundStyle(hasLeft ? .white : .light1)

                        if let place,
                           (isGroup && (1...3).contains(place)) ||
                           (!isGroup && place == 1) {
                            
                            Image(placeAssetName(place))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        
                        if showInfoIcon && !hasLeft {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.light1)
                                .transition(.opacity)
                        }
                        
                        if hasLeft {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(hasLeft ? Color.red1 : Color.light3)
                    )
                    
                    // Timer badge if under attack (only if NOT left)
                    if !hasLeft && isUnderSabotage, let expires = sabotageExpiresAt {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                            
                            Text(timeRemainingString(until: expires))
                                .font(.custom("RussoOne-Regular", size: 10))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red1))
                    }
                }
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Character sprite with red overlay if left
                Image(mapSprite)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
           
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 44, height: 14)
                .blur(radius: 1)
                .offset(y: -10)
               
               
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                if showBubble {
                    activePlayerBubbleId = nil
                } else {
                    activePlayerBubbleId = id
                }
            }
            onTap()  // Bring to front
        }
        .offset(dragOffset)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
        )
        .onChange(of: activePlayerBubbleId) { oldValue, newValue in
            if newValue == id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        if activePlayerBubbleId == id {
                            activePlayerBubbleId = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showInfoIcon = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Truncate name to first 5 characters
    private var truncatedName: String {
        if name.count <= 5 {
            return name
        }
        return String(name.prefix(5))
    }
    
    private func timeRemainingString(until date: Date) -> String {
        let remaining = Int(date.timeIntervalSince(Date()))
        if remaining <= 0 { return "0m" }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return hours > 0 ? "\(hours)h\(minutes)m" : "\(minutes)m"
    }
    
    private func placeAssetName(_ place: Int) -> String {
        if !isGroup {
            return "PlaceSolo"  // Solo place badge
        }
        
        switch place {
        case 1: return "Place1"
        case 2: return "Place2"
        case 3: return "Place3"
        default: return "Place1"
        }
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
    let goalSteps: Int
    let isChallengeEnded: Bool
    let hasLeft: Bool
    let leftAt: Date?
    let stepLengthMeters: Double

    var body: some View {
        VStack(spacing: 10) {

            // Name and Place
            HStack(spacing: 4) {
                Text(isMe ? "Me" : name)
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(.light1)

                if let place,
                   (isGroup && (1...3).contains(place)) ||
                   (!isGroup && place == 1) {

                    Image(placeAssetName(place))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }

            // Steps + (optional) KM
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                        .foregroundStyle(.light1)

                    Text("\(steps.formatted()) Steps")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(.light1)
                }
                
                HStack(spacing: 4) {
                    Image("km")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        
                    Text("≈ \(estimatedKmString(from: steps))")
                        .font(.custom("RussoOne-Regular", size: 10))
                        .foregroundStyle(.light1)
                    
                }
                
            }

            // Left info (replaces last sync)
            if hasLeft, let leftDate = leftAt {
                Divider().background(Color.red1.opacity(0.3))

                HStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.red1)

                    Text("Left \(leftText(leftDate))")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.red1)
                }

            } else if !isChallengeEnded && steps < goalSteps {
                // Last Sync (only if NOT left)
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 11))
                        .bold()
                        .foregroundStyle(.light2)

                    Text("Steps updated: \(formatDisplayDate(lastSyncedAt))")
                        .font(.custom("RussoOne-Regular", size: 10))
                        .foregroundStyle(.light2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Sabotage Info (only if NOT left)
            if !hasLeft && isUnderSabotage, let attackedByName {
                Divider().background(Color.red1.opacity(0.3))

                VStack(spacing: 4) {
                    Text("Under Attack!")
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.red1)

                    Text(isAttackedByMe ? "Turned lazy by you" : "Turned lazy by \(attackedByName)")
                        .font(.custom("RussoOne-Regular", size: 10))
                        .foregroundStyle(Color.red1)
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

    // MARK: - KM Estimation

    private func estimatedKilometers(from steps: Int) -> Double {
        let averageStepLength: Double = 0.75
        return (Double(steps) * averageStepLength) / 1000.0
    }

    private func estimatedKmString(from steps: Int) -> String {
        let km = estimatedKilometers(from: steps)
        return String(format: "%.2f km", km)
    }

    // MARK: - Existing Helpers

    private func leftText(_ date: Date) -> String {
        let formatted = formatDisplayDate(date)
        if formatted == "Today" || formatted == "Yesterday" {
            return formatted.lowercased()
        } else {
            return "on \(formatted)"
        }
    }

    private func formatDisplayDate (_ date: Date?) -> String {
        guard let date else { return "No Data" }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let daysDiff = calendar.dateComponents([.day],
                                              from: calendar.startOfDay(for: date),
                                              to: calendar.startOfDay(for: now)).day ?? 0

        if daysDiff > 0 && daysDiff < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }

        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func placeAssetName(_ place: Int) -> String {
        if !isGroup { return "PlaceSolo" }

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
