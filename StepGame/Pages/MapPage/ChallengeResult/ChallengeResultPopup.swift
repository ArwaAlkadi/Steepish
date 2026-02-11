//
//  ChallengeResultPopup.swift
//  StepGame
//

import Foundation
import SwiftUI
import Combine

// MARK: - Challenge Result Popup ViewModel
@MainActor
final class ChallengeResultPopupViewModel: ObservableObject {

    enum Mode { case solo, group }
    enum State { case win, lose }

    // MARK: - Row Model
    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let isMe: Bool
        let avatarImage: String
        let stepsText: String
        let place: Int?
        let didFinish: Bool
    }

    private let challenge: Challenge
    private let me: Player
    private let myParticipant: ChallengeParticipant
    private let participants: [ChallengeParticipant]
    private let playersById: [String: Player]

    @Published private(set) var mode: Mode
    @Published private(set) var state: State

    @Published private(set) var titleText: String = ""
    @Published private(set) var footerText: String = ""

    @Published private(set) var rows: [Row] = []

    @Published private(set) var soloResultImage: String = ""

    init(
        challenge: Challenge,
        me: Player,
        myParticipant: ChallengeParticipant,
        participants: [ChallengeParticipant],
        playersById: [String: Player] = [:]
    ) {
        self.challenge = challenge
        self.me = me
        self.myParticipant = myParticipant
        self.participants = participants
        self.playersById = playersById

        self.mode = (challenge.originalMode == .solo || challenge.maxPlayers == 1) ? .solo : .group
        self.state = (myParticipant.finishedAt != nil) ? .win : .lose

        buildUI()
    }

    // MARK: - Build UI
    private func buildUI() {
        titleText = (state == .win) ? "Well Done!" : "Oops!"

        let goal = challenge.goalSteps
        let originalDays = challenge.durationDays

        switch mode {

        case .solo:
            soloResultImage = resultAsset(for: me.characterType, didWin: (state == .win))

            if myParticipant.finishedAt != nil {
                let usedDays = daysUsedIfFinished()
                footerText = "\(goal.formatted()) Steps in \(usedDays) Days"
            } else {
                footerText = "You didn’t complete the \(goal.formatted())\nsteps in \(originalDays) days.. Try again!"
            }

        case .group:
            let timeEnded = Date() >= challenge.effectiveEndDate
            let iFinished = (myParticipant.finishedAt != nil)

            rows = buildGroupRows()

            if iFinished {
                let usedDays = daysUsedIfFinished()
                footerText = "\(goal.formatted()) Steps in \(usedDays) Days"
            } else {
                if challenge.winnerId != nil {
                    footerText = "\(goal.formatted()) Steps in \(originalDays) Days"
                } else if timeEnded {
                    footerText = "No one completed the \(goal.formatted())\nsteps in \(originalDays) days"
                } else {
                    footerText = "\(goal.formatted()) Steps in \(originalDays) Days"
                }
            }
        }
    }

    // ✅ يحسب الأيام الفعلية لإنهاء اللاعب (inclusive)
    private func daysUsedIfFinished() -> Int {
        guard let finishedAt = myParticipant.finishedAt else {
            return challenge.durationDays
        }

        let start = challenge.startedAt ?? challenge.startDate
        let cal = Calendar.current

        let startDay = cal.startOfDay(for: start)
        let finishDay = cal.startOfDay(for: finishedAt)

        let diff = (cal.dateComponents([.day], from: startDay, to: finishDay).day ?? 0) + 1
        return max(1, diff)
    }

    // MARK: - Group Rows
    private func buildGroupRows() -> [Row] {
        let myId = me.id ?? ""
        let winnerId = challenge.winnerId

        let finishers = participants
            .filter { $0.finishedAt != nil }
            .sorted { a, b in
                let ap = a.place ?? ((winnerId != nil && a.playerId == winnerId) ? 1 : Int.max)
                let bp = b.place ?? ((winnerId != nil && b.playerId == winnerId) ? 1 : Int.max)
                if ap != bp { return ap < bp }
                return a.steps > b.steps
            }

        let nonFinishers = participants
            .filter { $0.finishedAt == nil }
            .sorted { $0.steps > $1.steps }

        let combined = finishers + nonFinishers

        return combined.map { part in
            let isMeRow = (part.playerId == myId)
            let player = playersById[part.playerId] ?? (isMeRow ? me : nil)

            let displayName = player?.name ?? (isMeRow ? me.name : shortId(part.playerId))
            let avatar = avatarAsset(for: player?.characterType ?? .character1)

            let place: Int? = {
                if let p = part.place { return p }
                if let w = winnerId, part.playerId == w { return 1 }
                return nil
            }()

            return Row(
                name: displayName,
                isMe: isMeRow,
                avatarImage: avatar,
                stepsText: "\(part.steps.formatted()) Steps",
                place: place,
                didFinish: (part.finishedAt != nil)
            )
        }
    }

    private func avatarAsset(for type: CharacterType) -> String {
        "\(type.rawValue)_avatar"
    }

    // ✅ character1_win / character1_lose
    private func resultAsset(for type: CharacterType, didWin: Bool) -> String {
        let suffix = didWin ? "win" : "lose"
        return "\(type.rawValue)_\(suffix)"
    }

    private func shortId(_ id: String) -> String {
        if id.count <= 6 { return id }
        return "\(id.prefix(3))...\(id.suffix(3))"
    }
}

//
//  ChallengeResultPopupView.swift
//  StepGame
//

import SwiftUI
import Combine

// MARK: - Challenge Result Popup

struct ChallengeResultPopup: View {

    @Binding var isPresented: Bool
    @StateObject var vm: ChallengeResultPopupViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button { close() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.light1)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }

                Text(vm.titleText)
                    .font(.custom("RussoOne-Regular", size: 30))
                    .foregroundStyle(Color.light1)

                Group {
                    switch vm.mode {
                    case .group:
                        groupContent
                    case .solo:
                        soloContent
                    }
                }

                Text(vm.footerText)
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundStyle(Color.light1)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer(minLength: 0)
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

    private var groupContent: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.light4.opacity(0.75))

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 10) {
                        ForEach(vm.rows) { p in
                            GroupPlayerRow(p: p)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                }
            }
            .frame(height: 130)
        }
    }

    private var soloContent: some View {
        VStack(spacing: 10) {
            Image(vm.soloResultImage)
                .resizable()
                .scaledToFit()
                .frame(width: 300)
        }
        .frame(maxWidth: .infinity)
    }

    private func close() {
        withAnimation(.easeInOut) { isPresented = false }
    }
}

// MARK: - Group Player Row

private struct GroupPlayerRow: View {
    let p: ChallengeResultPopupViewModel.Row

    var body: some View {
        HStack(spacing: 10) {
            Image(p.avatarImage)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.light2.opacity(0.3)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {

                    if let place = p.place, (1...3).contains(place) {
                        Image(placeAssetName(place))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .padding(.bottom, 3)
                    }

                    Text(p.name + (p.isMe ? " (Me)" : ""))
                        .font(.custom("RussoOne-Regular", size: 14))
                        .foregroundStyle(Color.light1)
                }

                Text(p.stepsText)
                    .font(.custom("RussoOne-Regular", size: 11))
                    .foregroundStyle(Color.light1.opacity(0.75))
            }

            Spacer()
        }
        .padding(.horizontal, 6)
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
