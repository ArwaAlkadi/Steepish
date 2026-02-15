//
//  WaitingViewModel.swift
//  StepGame
//
//

import Foundation
import SwiftUI
import UIKit
import Combine
import FirebaseFirestore

// MARK: - Lobby Player

struct LobbyPlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let isMe: Bool
    let avatarAsset: String
}

// MARK: - Waiting Room ViewModel

final class WaitingRoomViewModel: ObservableObject {

    @Published private(set) var lobbyPlayers: [LobbyPlayer] = []
    @Published private(set) var isHost: Bool = false
    @Published private(set) var isStarting: Bool = false

    @Published private(set) var challenge: Challenge? = nil
    @Published private(set) var participants: [ChallengeParticipant] = []

    @Published private(set) var playersById: [String: Player] = [:]

    private weak var session: GameSession?
    private let firebase = FirebaseService.shared

    private var challengeListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?

    deinit { unbind() }

    var titleText: String { challenge?.name ?? "Waiting..." }

    var goalStepsText: String {
        guard let ch = challenge else { return "" }
        return "\(ch.goalSteps.formatted()) Steps"
    }

    var joinCodeText: String { (challenge?.joinCode ?? "").uppercased() }

    var footerTextForPlayer: String {
        "Waiting for the host to\nstart the challenge"
    }

    var canStart: Bool {
        guard let ch = challenge else { return false }
        guard ch.status == .waiting else { return false }
        if ch.originalMode == .social { return ch.playerIds.count >= 2 }
        return true
    }

    private var isHostComputed: Bool {
        guard let ch = challenge else { return false }
        let myId = session?.uid ?? session?.player?.id ?? ""
        return ch.createdBy == myId
    }

    var leaveAlertTitle: String { isHostComputed ? "Delete Challenge?" : "Leave Challenge?" }

    var leaveAlertMessage: String {
        isHostComputed
            ? "This will permanently delete the challenge for everyone."
            : "You will leave this challenge."
    }

    var leaveAlertActionTitle: String { isHostComputed ? "Delete" : "Leave" }

    // MARK: - Bind / Unbind

    func bind(session: GameSession) {
        self.session = session
        unbind()

        self.challenge = session.challenge
        refreshUI()

        guard let chId = session.challenge?.id else { return }

        challengeListener = firebase.listenChallenge(challengeId: chId) { [weak self] updated in
            guard let self else { return }
            DispatchQueue.main.async {
                self.challenge = updated
                self.session?.challenge = updated
                self.refreshUI()
            }
        }

        participantsListener = firebase.listenParticipants(challengeId: chId) { [weak self] list in
            guard let self else { return }
            DispatchQueue.main.async {
                self.participants = list
            }
            Task { @MainActor in
                await self.fetchPlayersIfNeeded()
                self.refreshUI()
            }
        }
    }

    func unbind() {
        challengeListener?.remove()
        challengeListener = nil
        participantsListener?.remove()
        participantsListener = nil
    }

    // MARK: - Actions

    func copyJoinCode() {
        UIPasteboard.general.string = joinCodeText
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func startChallenge() async {
        guard canStart else { return }
        guard let session else { return }

        DispatchQueue.main.async { self.isStarting = true }
        defer { DispatchQueue.main.async { self.isStarting = false } }

        await session.startSelectedChallengeIfHost()
    }

    func leaveOrDeleteChallenge() async {
        guard let session else { return }
        guard let ch = challenge else { return }

        if isHostComputed {
            await session.deleteChallenge(ch)
        } else {
            await session.leaveChallenge(ch)
        }
    }

    // MARK: - Players Fetching

    private func fetchPlayersIfNeeded() async {
        guard let ch = challenge else { return }
        let ids = Array(ch.playerIds.prefix(4))

        let missing = ids.filter { playersById[$0] == nil }
        guard !missing.isEmpty else { return }

        do {
            let fetched = try await firebase.fetchPlayers(uids: missing)
            var dict = playersById
            for p in fetched {
                if let id = p.id { dict[id] = p }
            }
            playersById = dict
        } catch {
        }
    }

    // MARK: - UI Update

    private func refreshUI() {
        guard let session else { return }
        guard let ch = challenge else { return }

        let myId = session.uid ?? session.player?.id ?? ""
        let host = (ch.createdBy == myId)

        let players = makeLobbyPlayers(challenge: ch, session: session)

        DispatchQueue.main.async {
            self.isHost = host
            self.lobbyPlayers = players
        }
    }

    private func makeLobbyPlayers(challenge: Challenge, session: GameSession) -> [LobbyPlayer] {
        let ids = Array(challenge.playerIds.prefix(4))
        let myId = session.player?.id ?? session.uid ?? ""

        return ids.map { pid in
            let isMe = (pid == myId)

            /// Resolve player model for name and character
            let p = playersById[pid] ?? (isMe ? session.player : nil)

            let name = p?.name ?? (isMe ? "Me" : shortId(pid))
            let type = p?.characterType ?? .character1

            /// Use avatar asset for lobby UI
            let avatarAsset = type.avatarKey()

            return LobbyPlayer(
                id: pid,
                name: name,
                isMe: isMe,
                avatarAsset: avatarAsset
            )
        }
    }

    /// Shortens a uid for display
    private func shortId(_ id: String) -> String {
        if id.count <= 6 { return id }
        return "\(id.prefix(3))...\(id.suffix(3))"
    }
    
    var playerCountText: String {
        let current = challenge?.playerIds.count ?? lobbyPlayers.count
        let max = challenge?.maxPlayers ?? 4
        return "\(current)/\(max)"
    }
}
