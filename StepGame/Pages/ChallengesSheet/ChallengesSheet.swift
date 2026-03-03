//
//  ChallengesSheet.swift
//  StepGame
//

import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Challenges Sheet

struct ChallengesSheet: View {

    @EnvironmentObject private var session: GameSession

    var onTapCreate: () -> Void = {}
    var onTapJoin: () -> Void = {}
    var onTapChallenge: (Challenge) -> Void = { _ in }

    // Rename state
    @State private var showRenamePopup = false
    @State private var challengeToRename: Challenge? = nil
    @State private var pendingNewName = ""

    // Confirm delete/leave state
    @State private var showConfirmPopup = false
    @State private var challengeToConfirm: Challenge? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.light3.ignoresSafeArea(edges: .all)

                VStack(spacing: 16) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {

                            let activeChallenges = session.activeChallenges

                            if !activeChallenges.isEmpty {
                                ForEach(activeChallenges) { ch in
                                    Button { onTapChallenge(ch) } label: {
                                        ChallengesCard(
                                            challenge: ch,
                                            badgeText: badgeForChallenge(ch),
                                            onRename: { challenge in
                                                pendingNewName = challenge.name
                                                challengeToRename = challenge
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    showRenamePopup = true
                                                }
                                            },
                                            onConfirmAction: { challenge in
                                                challengeToConfirm = challenge
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    showConfirmPopup = true
                                                }
                                            }
                                        )
                                        .environmentObject(session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                emptyState.padding(.top, 40)
                            }

                            let endedChallenges = session.endedChallenges

                            if !endedChallenges.isEmpty {
                                Text("Ended")
                                    .font(.custom("RussoOne-Regular", size: 20))
                                    .foregroundStyle(.light1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top)

                                Divider()

                                ForEach(endedChallenges) { ch in
                                    Button { onTapChallenge(ch) } label: {
                                        ChallengesCard(
                                            challenge: ch,
                                            badgeText: badgeForChallenge(ch),
                                            onRename: { challenge in
                                                pendingNewName = challenge.name
                                                challengeToRename = challenge
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    showRenamePopup = true
                                                }
                                            },
                                            onConfirmAction: { challenge in
                                                challengeToConfirm = challenge
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    showConfirmPopup = true
                                                }
                                            }
                                        )
                                        .environmentObject(session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()

                // Rename popup
                if showRenamePopup {
                    RenamePopup(
                        isPresented: $showRenamePopup,
                        name: $pendingNewName,
                        onDone: {
                            let trimmed = pendingNewName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty, let ch = challengeToRename else { return }
                            await session.renameChallenge(ch, newName: trimmed)
                        }
                    )
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // Confirm delete/leave popup
                if showConfirmPopup, let ch = challengeToConfirm {
                    let isHost = ch.createdBy == session.uid
                    ConfirmPopup(
                        isPresented: $showConfirmPopup,
                        title: isHost ? "Delete \"\(ch.name)\"?" : "Leave \"\(ch.name)\"?",
                        message: isHost
                            ? "This will remove the challenge for everyone. This can't be undone."
                            : "You'll leave this challenge and stop syncing steps for it.",
                        actionTitle: isHost ? "Delete" : "Leave",
                        cancelTitle: "Cancel",
                        onConfirm: {
                            if isHost {
                                await session.deleteChallenge(ch)
                            } else {
                                await session.leaveChallenge(ch)
                            }
                        }
                    )
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Challenges")
                .font(.custom("RussoOne-Regular", size: 35))
                .bold()
                .foregroundStyle(.light1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button { onTapCreate() } label: { Text("Add a New Challenge") }
                Button { onTapJoin() } label: { Text("Join With Code") }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.light1)
            }
            .buttonStyle(.plain)
        }
        .padding(.top)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No active challenges")
                .font(.custom("RussoOne-Regular", size: 16))
                .foregroundColor(.light1.opacity(0.4))
        }
    }

    private func badgeForChallenge(_ ch: Challenge) -> String? {
        if ch.originalMode == .solo { return "Solo" }
        if ch.status == .waiting { return "Waiting" }
        if ch.status == .active { return "Active" }
        return nil
    }
}

// MARK: - Rename Popup

struct RenamePopup: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    var onDone: () async -> Void
    
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isProcessing {
                        dismiss()
                    }
                }

            VStack(spacing: 18) {

                // X button top-right
                HStack {
                    Spacer()
                    Button {
                        if !isProcessing {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.light1)
                    }
                    .buttonStyle(.plain)
                }
               

                // Title
                Text("Enter new challenge name")
                    .font(.custom("RussoOne-Regular", size: 18))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
                   

                // Text field + Counter
                VStack(spacing: 8) {
                    TextField("", text: $name)
                        .font(.custom("RussoOne-Regular", size: 16))
                        .foregroundStyle(Color.light1)
                        .tint(Color.light1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.light4)
                        )
                        .padding(.horizontal, 16)
                        .disabled(isProcessing)
                        .opacity(isProcessing ? 0.5 : 1)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 15 {
                                name = String(newValue.prefix(15))
                            }
                            errorMessage = nil
                        }
                    
                    // ✅ Character counter
                    HStack {
                        Text("\(name.count)/15")
                            .font(.custom("RussoOne-Regular", size: 12))
                            .foregroundStyle(Color.light2)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }
                
                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Done button
                Button {
                    guard !isProcessing else { return }
                    
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    
                    guard !trimmed.isEmpty else {
                        errorMessage = "Name cannot be empty"
                        return
                    }
                    
                    guard trimmed.count <= 15 else {
                        errorMessage = "Name must be 15 characters or less"
                        return
                    }
                    
                    Task {
                        isProcessing = true
                        await onDone()
                        isProcessing = false
                        dismiss()
                    }
                } label: {
                    Text(isProcessing ? "Saving..." : "Done")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(.light3)
                        .frame(width: 160)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.light1)
                        )
                }
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.5 : 1)
                .padding(.top, 10)
            }
            .padding(20)
            .padding(.bottom, 25)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.light3)
            )
        }
    }

    private func dismiss() {
        errorMessage = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Confirm Popup (Delete / Leave)

struct ConfirmPopup: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let actionTitle: String
    let cancelTitle: String
    var onConfirm: () async -> Void
    
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 18) {

                // X button top-right
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.light1)
                    }
                    .buttonStyle(.plain)
                }
              

                // Title
                Text(title)
                    .font(.custom("RussoOne-Regular", size: 18))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
                

                // Message
                Text(message)
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(Color.light2)
                    .multilineTextAlignment(.center)
                   
                HStack(spacing: 12) {
                    // Cancel button
                    Button {
                        dismiss()
                    } label: {
                        Text(cancelTitle)
                            .font(.custom("RussoOne-Regular", size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 130)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .foregroundStyle(.light1)
                            )
                    }
                    
                    // Confirm button
                    Button {
                        guard !isProcessing else { return }
                        
                        Task {
                            isProcessing = true
                            await onConfirm()
                            isProcessing = false
                            dismiss()
                        }
                    } label: {
                        Text(isProcessing ? "\(actionTitle)ing..." : actionTitle)
                            .font(.custom("RussoOne-Regular", size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 130)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.7 : 1)
                    .padding(.top, 10)
                }
               
            }
            .padding(20)
            .padding(.bottom, 25)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.light3)
            )
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Challenges Card

struct ChallengesCard: View {

    @EnvironmentObject private var session: GameSession

    let challenge: Challenge
    var badgeText: String? = nil
    var onRename: (Challenge) -> Void = { _ in }
    var onConfirmAction: (Challenge) -> Void = { _ in }

    @State private var myPlaceForThisChallenge: Int? = nil
    @State private var placeListener: ListenerRegistration? = nil

    private let firebase = FirebaseService.shared

    private var isHost: Bool {
        guard let uid = session.uid else { return false }
        return challenge.createdBy == uid
    }

    private var actionTitle: String { isHost ? "Delete" : "Leave" }

    var body: some View {
        HStack {

            VStack(alignment: .leading, spacing: 10) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.custom("RussoOne-Regular", size: 20))
                        .foregroundStyle(.light1)

                    Text(dateRangeText())
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(.light1.opacity(0.7))
                }

                HStack(spacing: 10) {

                    HStack(spacing: 4) {
                        Image("Target")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .padding(.horizontal, 3)

                        Text("\(challenge.goalSteps.formatted())")
                            .font(.custom("RussoOne-Regular", size: 14))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.light2))

                    Text(statusTitle(challenge.status))
                        .font(.custom("RussoOne-Regular", size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(statusColor(challenge.status)))

                    if let crown = crownImageName {
                        Image(crown)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                    }

                    Spacer()
                }
            }
            .padding()

            VStack {
                Menu {
                    if isHost {
                        Button {
                            onRename(challenge)
                        } label: {
                            Text("Rename")
                        }
                    }

                    Button(role: .destructive) {
                        onConfirmAction(challenge)
                    } label: {
                        Text(actionTitle)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .bold()
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(.light1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(challenge.playerIds.count)")
                        .font(.custom("RussoOne-Regular", size: 14))
                    Image(systemName: systemIconName(for: challenge.playerIds.count))
                }
                .foregroundStyle(.light1)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.light4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onAppear { attachPlaceListenerIfNeeded() }
        .onDisappear {
            placeListener?.remove()
            placeListener = nil
        }
    }

    private func attachPlaceListenerIfNeeded() {
        guard challenge.status == .ended else {
            myPlaceForThisChallenge = nil
            placeListener?.remove()
            placeListener = nil
            return
        }

        guard let chId = challenge.id, let uid = session.uid else { return }

        placeListener?.remove()
        placeListener = firebase.listenMyParticipant(challengeId: chId, uid: uid) { part in
            DispatchQueue.main.async {
                self.myPlaceForThisChallenge = part?.place
            }
        }
    }

    private func statusTitle(_ s: ChallengeStatus) -> String {
        switch s {
        case .waiting: return "Waiting"
        case .active:  return "Active"
        case .ended:   return "Ended"
        }
    }

    private func statusColor(_ s: ChallengeStatus) -> Color {
        switch s {
        case .waiting: return .orange
        case .active:  return Color("Green1")
        case .ended:   return .red
        }
    }

    private func systemIconName(for count: Int) -> String {
        count <= 1 ? "person.fill" : "person.2.fill"
    }

    private func dateRangeText() -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: challenge.startDate)
        let endYear = calendar.component(.year, from: challenge.effectiveEndDate)

        let formatter = DateFormatter()
        if startYear == currentYear && endYear == currentYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        let start = formatter.string(from: challenge.startDate)
        let end = formatter.string(from: challenge.effectiveEndDate)
        return "\(start) - \(end)"
    }

    private var crownImageName: String? {
        guard challenge.status == .ended else { return nil }
        guard let place = myPlaceForThisChallenge else { return nil }

        let playerCount = challenge.playerIds.count
        if playerCount == 1 { return "PlaceSolo" }

        switch place {
        case 1: return "Place1"
        case 2: return "Place2"
        case 3: return "Place3"
        default: return nil
        }
    }
}
