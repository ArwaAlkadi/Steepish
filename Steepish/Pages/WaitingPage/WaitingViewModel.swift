//
//  WaitingViewModel.swift
//  Steepish
//

import Foundation
import SwiftUI
import UIKit
import Combine
import FirebaseFirestore

// MARK: - Lobby Player

/// Display data for a single player shown in the waiting room lobby.
struct LobbyPlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let isMe: Bool
    let avatarAsset: String
}

// MARK: - Waiting Room ViewModel

/// Backs `WaitingRoomView`: binds to the selected challenge and its participants, and
/// exposes the host start/leave actions.
final class WaitingRoomViewModel: ObservableObject {

    @Published private(set) var lobbyPlayers: [LobbyPlayer] = []
    @Published private(set) var isHost: Bool = false
    @Published private(set) var isStarting: Bool = false

    @Published private(set) var challenge: Challenge? = nil
    @Published private(set) var participants: [ChallengeParticipant] = []

    @Published private(set) var playersById: [String: Player] = [:]

    private weak var session: UserSession?
    private let firebase = FirebaseService.shared

    private var challengeListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?

    deinit { unbind() }

    /// The challenge's display name, or a placeholder while loading.
    var titleText: String { challenge?.name ?? "Waiting..." }

    /// "N Steps" label for the challenge's goal.
    var goalStepsText: String {
        guard let ch = challenge else { return "" }
        return "\(ch.goalSteps.formatted()) Steps"
    }

    /// "N Days" label for the challenge's duration.
    var durationText: String {
        guard let ch = challenge else { return "" }
        let days = ch.durationDays
        let word = days == 1 ? "Day" : "Days"
        return "\(days) \(word)"
    }

    /// Combined "N Steps in N Days" label.
    var goalAndDurationText: String {
        guard let ch = challenge else { return "" }
        let steps = "\(ch.goalSteps.formatted()) Steps"
        let days = durationText
        return "\(steps) in \(days)"
    }

    /// The challenge's join code, uppercased for display.
    var joinCodeText: String { (challenge?.joinCode ?? "").uppercased() }

    /// Footer copy shown to non-host players.
    var footerTextForPlayer: String {
        "Waiting for the host to\nstart the challenge"
    }

    /// Whether the challenge currently has enough players (and is still waiting) to be started.
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

    /// Title for the leave/delete confirmation, depending on host status.
    var leaveAlertTitle: String { isHostComputed ? "Delete Challenge?" : "Leave Challenge?" }

    /// Message for the leave/delete confirmation, depending on host status.
    var leaveAlertMessage: String {
        isHostComputed
            ? "This will permanently delete the challenge for everyone."
            : "You will leave this challenge."
    }

    /// Action button title for the leave/delete confirmation, depending on host status.
    var leaveAlertActionTitle: String { isHostComputed ? "Delete" : "Leave" }

    // MARK: - Bind / Unbind

    /// Binds to the session's selected challenge and attaches its Firestore listeners.
    func bind(session: UserSession) {
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

    /// Removes the Firestore listeners attached in `bind(session:)`.
    func unbind() {
        challengeListener?.remove()
        challengeListener = nil
        participantsListener?.remove()
        participantsListener = nil
    }

    // MARK: - Actions

    /// Copies the join code to the clipboard with a light haptic tap.
    func copyJoinCode() {
        UIPasteboard.general.string = joinCodeText
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Starts the challenge, if eligible.
    func startChallenge() async {
        guard canStart else { return }
        guard let session else { return }

        DispatchQueue.main.async { self.isStarting = true }
        defer { DispatchQueue.main.async { self.isStarting = false } }

        await session.startSelectedChallengeIfHost()
    }

    /// Deletes the challenge (host) or leaves it (non-host participant).
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

    private func makeLobbyPlayers(challenge: Challenge, session: UserSession) -> [LobbyPlayer] {
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

    /// Shortens a uid for display.
    private func shortId(_ id: String) -> String {
        if id.count <= 6 { return id }
        return "\(id.prefix(3))...\(id.suffix(3))"
    }

    /// "current/max" player count label.
    var playerCountText: String {
        let current = challenge?.playerIds.count ?? lobbyPlayers.count
        let max = challenge?.maxPlayers ?? 4
        return "\(current)/\(max)"
    }
}

