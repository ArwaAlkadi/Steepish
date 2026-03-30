//
//  GameSession.swift
//  StepGame
//

import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class GameSession: ObservableObject {

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isPresentingSetupChallenge: Bool = false

    // MARK: - Auth / Player
    @Published private(set) var uid: String? = nil
    @Published var player: Player? = nil
    @Published var playerName: String = ""

    // MARK: - Challenge Navigation
    @Published var challenge: Challenge? = nil

    // MARK: - Challenges List
    @Published var challenges: [Challenge] = []

    var activeChallenges: [Challenge] { challenges.filter { $0.status == .active } }
    var endedChallenges: [Challenge] { challenges.filter { $0.status == .ended } }
    var hasAnyChallenges: Bool { !challenges.isEmpty }

    // MARK: - Participants (Selected Challenge)
    @Published private(set) var participants: [ChallengeParticipant] = []
    @Published private(set) var myParticipant: ChallengeParticipant? = nil

    // MARK: - Pending Challenge
    private var pendingChallengeId: String? = nil

    // MARK: - Private
    private let firebase = FirebaseService.shared

    private var myChallengesListener: ListenerRegistration?
    private var selectedChallengeListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?

    private var stepSyncCancellable: AnyCancellable?

    // MARK: - Init
    
    init() {
        NotificationCenter.default.addObserver(
            forName: .navigateToChallenge,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let challengeId = notification.userInfo?["challengeId"] as? String {
                if let ch = self.challenges.first(where: { $0.id == challengeId }) {
                    self.selectChallenge(ch)
                } else {
                    self.pendingChallengeId = challengeId
                }
            }
        }
    }

    deinit {
        myChallengesListener?.remove()
        selectedChallengeListener?.remove()
        participantsListener?.remove()
        stepSyncCancellable?.cancel()
    }

    // MARK: - Bootstrapping
    func bootstrap() async {
        if uid != nil { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let signedUid = try await firebase.signInIfNeeded()
            uid = signedUid

            do {
                let p = try await firebase.fetchPlayer(uid: signedUid)
                player = p
                playerName = p.name
                startMyChallengesListener(uid: signedUid)
            } catch {
                player = nil
                playerName = ""
            }
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    // MARK: - Challenge List Listener
    private func startMyChallengesListener(uid: String) {
        myChallengesListener?.remove()

        myChallengesListener = firebase.listenMyChallenges(uid: uid) { [weak self] list in
            guard let self else { return }
            Task { @MainActor in
                self.challenges = list

                if let pendingId = self.pendingChallengeId,
                   let ch = list.first(where: { $0.id == pendingId }) {
                    self.selectChallenge(ch)
                    self.pendingChallengeId = nil
                    return
                }

                let selectedId = self.challenge?.id
                let stillExists = selectedId.flatMap { id in
                    list.contains(where: { $0.id == id })
                } ?? false

                if !stillExists {
                    self.challenge = self.pickDefaultChallenge(from: list)
                }

                if let id = self.challenge?.id {
                    self.startSelectedChallengeListener(challengeId: id)
                    self.startParticipantsListenerIfNeeded(challengeId: id)
                }
            }
        }
    }

    private func pickDefaultChallenge(from list: [Challenge]) -> Challenge? {
        if let active = list.first(where: { $0.status == .active }) { return active }
        if let waiting = list.first(where: { $0.status == .waiting }) { return waiting }
        return list.first
    }

    // MARK: - Selected Challenge Listener
    private func startSelectedChallengeListener(challengeId: String) {
        selectedChallengeListener?.remove()

        selectedChallengeListener = firebase.listenChallenge(challengeId: challengeId) { [weak self] updated in
            guard let self else { return }
            Task { @MainActor in
                guard let updated else {
                    self.challenge = nil
                    self.participants = []
                    self.myParticipant = nil
                    return
                }

                self.challenge = updated

                if let id = updated.id {
                    self.startParticipantsListenerIfNeeded(challengeId: id)
                }
            }
        }
    }

    private func startParticipantsListenerIfNeeded(challengeId: String) {
        participantsListener?.remove()

        participantsListener = firebase.listenParticipants(challengeId: challengeId) { [weak self] list in
            guard let self else { return }
            Task { @MainActor in
                self.participants = list
                self.recomputeMyParticipant()
            }
        }
    }

    // MARK: - Participant Selection
    private func recomputeMyParticipant() {
        guard let uid else {
            myParticipant = nil
            return
        }
        myParticipant = participants.first(where: { $0.playerId == uid })
    }

    // MARK: - Selection & Presentation
    func selectChallenge(_ ch: Challenge) {
        challenge = ch
        participants = []
        myParticipant = nil

        if let id = ch.id {
            startSelectedChallengeListener(challengeId: id)
            startParticipantsListenerIfNeeded(challengeId: id)
        }
    }

    func presentSetupChallenge() {
        isPresentingSetupChallenge = true
    }

    // MARK: - Results Helpers
    func isChallengeInResultState(_ ch: Challenge, now: Date = Date()) -> Bool {
        (ch.winnerId != nil) || (now >= ch.effectiveEndDate) || (ch.status == .ended)
    }

    // MARK: - Player
    func createPlayer(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let uid else {
            errorMessage = "Missing user session."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let p = try await firebase.createOrUpdatePlayer(
                uid: uid,
                name: trimmed,
                characterType: .character1
            )
            player = p
            playerName = p.name
            startMyChallengesListener(uid: uid)
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    // MARK: - Create Challenge
    @discardableResult
    func createNewChallenge(
        name: String,
        mode: ChallengeMode,
        goalSteps: Int,
        durationDays: Int
    ) async -> String? {
        guard let uid else {
            let msg = "Missing user session."
            errorMessage = msg
            return msg
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let ch = try await firebase.createChallenge(
                hostUid: uid,
                name: name,
                mode: mode,
                goalSteps: goalSteps,
                durationDays: durationDays
            )
            selectChallenge(ch)
            return nil
        } catch {
            let msg = mapGenericError(error)
            errorMessage = msg
            return msg
        }
    }

    // MARK: - Join With Code
    @discardableResult
    func joinWithCode(_ code: String) async -> String? {
        guard let uid else {
            let msg = "Missing user session."
            errorMessage = msg
            return msg
        }

        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 4 else {
            let msg = "Invalid code. Try again."
            errorMessage = msg
            return msg
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let ch = try await firebase.joinChallenge(by: cleaned, uid: uid)
            selectChallenge(ch)
            return nil
        } catch {
            let msg = mapJoinError(error)
            errorMessage = msg
            return msg
        }
    }

    // MARK: - Start Challenge (Host)
    func startSelectedChallengeIfHost() async {
        guard let uid else {
            errorMessage = "Missing user session."
            return
        }
        guard let ch = challenge, let challengeId = ch.id else {
            errorMessage = "Missing challenge."
            return
        }
        guard ch.createdBy == uid else {
            errorMessage = "Only the host can start this challenge."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await firebase.startChallenge(challengeId: challengeId, hostUid: uid)
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    // MARK: - Steps Sync
    func beginStepsSync(health: HealthKitManager) {
        stepSyncCancellable?.cancel()

        stepSyncCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .prepend(Date())
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.syncMyStepsOnce(health: health) }
            }
    }

    func stopStepsSync() {
        stepSyncCancellable?.cancel()
        stepSyncCancellable = nil
    }

    func syncMyStepsOnce(health: HealthKitManager) async {
        guard let uid else { return }
        guard let ch = challenge, let challengeId = ch.id else { return }

        guard ch.status == .active else { return }
        guard health.isAuthorized else { return }

        do {
            let start = ch.startedAt ?? ch.startDate
            let steps = try await health.fetchSteps(from: start, to: Date())

            let goal = max(ch.goalSteps, 1)
            let progress = min(max(Double(steps) / Double(goal), 0), 1)

            let state: CharacterState = (progress >= 1.0) ? .active : .normal

            try await firebase.updateParticipantSteps(
                challengeId: challengeId,
                uid: uid,
                steps: steps,
                progress: progress,
                characterState: state
            )
        } catch {
        }
    }

    // MARK: - Delete / Leave / Waiting Logic/ Rename
    func deleteChallenge(_ ch: Challenge) async {
        guard let uid else {
            errorMessage = "Missing user session."
            return
        }
        guard let id = ch.id else { return }
        guard ch.createdBy == uid else {
            errorMessage = "Only the host can delete this challenge."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await firebase.deleteChallenge(challengeId: id)

            if self.challenge?.id == id {
                self.challenge = self.pickDefaultChallenge(from: self.challenges.filter { $0.id != id })
            }
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    func leaveChallenge(_ ch: Challenge) async {
        guard let uid else {
            errorMessage = "Missing user session."
            return
        }
        guard let id = ch.id else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await firebase.leaveChallenge(challengeId: id, uid: uid)

            if self.challenge?.id == id {
                self.challenge = self.pickDefaultChallenge(from: self.challenges.filter { $0.id != id })
            }
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    func handleExitWaitingRoomIfStillWaiting() async {
        guard let uid else { return }
        guard let ch = challenge, let id = ch.id else { return }
        guard ch.status == .waiting else { return }

        do {
            if ch.createdBy == uid {
                try await firebase.deleteChallenge(challengeId: id)
            } else {
                try await firebase.leaveChallenge(challengeId: id, uid: uid)
            }

            self.challenge = self.pickDefaultChallenge(from: self.challenges.filter { $0.id != id })
            self.participants = []
            self.myParticipant = nil

        } catch {
            self.errorMessage = mapGenericError(error)
        }
    }
    
    func renameChallenge(_ challenge: Challenge, newName: String) async {
        guard let id = challenge.id else { return }
        do {
            try await FirebaseService.shared.renameChallenge(
                challengeId: id,
                newName: newName
            )
            // The realtime listener on "challenges" will automatically
            // push the updated Challenge model back to activeChallenges /
            // endedChallenges, so no manual local mutation is needed.
        } catch {
            print("❌ renameChallenge error: \(error.localizedDescription)")
        }
    }


    // MARK: - Convenience
    func clearError() {
        errorMessage = nil
    }

    func updateProfile(name: String, characterType: CharacterType) async {
        guard let uid else {
            errorMessage = "Missing user session."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updated = try await firebase.updatePlayerProfile(
                uid: uid,
                name: name,
                characterType: characterType
            )
            player = updated
            playerName = updated.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Error Mapping
    private func mapJoinError(_ error: Error) -> String {
        let ns = error as NSError

        if ns.domain == "Join" {
            switch ns.code {
            case 404: return "Code not found. Please check and try again."
            case 409: return "This challenge is full."
            case 400: return "Something went wrong. Please try again."
            default:  return ns.localizedDescription
            }
        }

        let desc = ns.localizedDescription.lowercased()
        if desc.contains("network") || desc.contains("offline") || desc.contains("no network") || desc.contains("unavailable") {
            return "No internet connection. Please try again."
        }
        if desc.contains("permission") || desc.contains("not authorized") || desc.contains("unauth") {
            return "You don’t have permission to join right now."
        }

        return "Couldn’t join. Please try again."
    }

    private func mapGenericError(_ error: Error) -> String {
        let ns = error as NSError
        let desc = ns.localizedDescription.lowercased()

        if desc.contains("network") || desc.contains("offline") || desc.contains("unavailable") {
            return "No internet connection. Please try again."
        }

        return ns.localizedDescription
    }
    
}
