//
//  ChallengesSheet.swift
//  StepGame
//

import SwiftUI
import Combine
import FirebaseFirestore

struct ChallengesSheet: View {

    @EnvironmentObject private var session: GameSession

    var onTapCreate: () -> Void = {}
    var onTapJoin: () -> Void = {}

    var onTapChallenge: (Challenge) -> Void = { _ in }

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
                                    Button {
                                        onTapChallenge(ch)
                                    } label: {
                                        ChallengesCard(
                                            challenge: ch,
                                            badgeText: badgeForChallenge(ch),
                                            showMenu: true
                                        )
                                        .environmentObject(session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                emptyState
                                    .padding(.top, 40)
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
                                    Button {
                                        onTapChallenge(ch)
                                    } label: {
                                        ChallengesCard(
                                            challenge: ch,
                                            badgeText: badgeForChallenge(ch),
                                            showMenu: false
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
    }

    // \\ Empty state
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No active challenges")
                .font(.custom("RussoOne-Regular", size: 16))
                .foregroundColor(.light1.opacity(0.4))
        }
    }

    // \\ Badge label for a challenge
    private func badgeForChallenge(_ ch: Challenge) -> String? {
        if ch.originalMode == .solo { return "Solo" }
        if ch.status == .waiting { return "Waiting" }
        if ch.status == .active { return "Active" }
        return nil
    }
}

// MARK: - Challenges Card

struct ChallengesCard: View {

    @EnvironmentObject private var session: GameSession

    let challenge: Challenge
    var badgeText: String? = nil
    var showMenu: Bool = true

    @State private var showConfirmAlert = false

    @State private var myPlaceForThisChallenge: Int? = nil
    @State private var placeListener: ListenerRegistration? = nil

    private let firebase = FirebaseService.shared

    private var isHost: Bool {
        guard let uid = session.uid else { return false }
        return challenge.createdBy == uid
    }

    private var actionTitle: String { isHost ? "Delete" : "Leave" }
    private var alertTitle: String { isHost ? "Delete Challenge?" : "Leave Challenge?" }

    private var alertMessage: String {
        isHost
            ? "This will permanently delete the challenge for everyone."
            : "You will leave this challenge."
    }

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

                if showMenu {
                    Menu {
                        Button(role: .destructive) {
                            showConfirmAlert = true
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
        .alert(alertTitle, isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) {}

            Button(actionTitle, role: .destructive) {
                Task {
                    if isHost {
                        await session.deleteChallenge(challenge)
                    } else {
                        await session.leaveChallenge(challenge)
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            attachPlaceListenerIfNeeded()
        }
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

        guard let chId = challenge.id else { return }
        guard let uid = session.uid else { return }

        placeListener?.remove()
        placeListener = firebase.listenMyParticipant(challengeId: chId, uid: uid) { part in
            DispatchQueue.main.async {
                self.myPlaceForThisChallenge = part?.place
            }
        }
    }

    /// Status title label
    private func statusTitle(_ s: ChallengeStatus) -> String {
        switch s {
        case .waiting: return "Waiting"
        case .active:  return "Active"
        case .ended:   return "Ended"
        }
    }

    /// Status background color
    private func statusColor(_ s: ChallengeStatus) -> Color {
        switch s {
        case .waiting: return .orange
        case .active:  return Color("Green1")
        case .ended:   return Color("Red1")
        }
    }

    /// Player count icon
    private func systemIconName(for count: Int) -> String {
        count <= 1 ? "person.fill" : "person.2.fill"
    }

    /// Date Format
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

        if playerCount == 1 {
            return "PlaceSolo"
        }

        switch place {
        case 1: return "Place1"
        case 2: return "Place2"
        case 3: return "Place3"
        default: return nil
        }
    }
}
