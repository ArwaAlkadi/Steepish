//
//  MapViewModel.swift
//  StepGame
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import UIKit
import WidgetKit

@MainActor
final class MapViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var challenge: Challenge? = nil
    @Published private(set) var participants: [ChallengeParticipant] = []
    @Published private(set) var playersById: [String: Player] = [:]
    @Published private(set) var myParticipant: ChallengeParticipant? = nil

    @Published var pendingMapPopup: MapPopupType? = nil

    @Published var isShowingResultPopup: Bool = false
    @Published var resultPopupVM: ChallengeResultPopupViewModel? = nil

    struct MapPlayerVM: Identifiable {
        let id: String
        let name: String
        let hudAvatar: String
        let mapSprite: String
        let steps: Int
        let progress: Double
        let isMe: Bool
        let place: Int?
        
        let attackedByName: String?
        let isUnderSabotage: Bool
        let sabotageExpiresAt: Date?
        let isAttackedByMe: Bool
        let lastSyncedAt: Date?
        let isChallengeEnded: Bool
        
        let hasLeft: Bool
        let leftAt: Date?
    }

    @Published private(set) var mapPlayers: [MapPlayerVM] = []

    @Published private(set) var activePlayerId: String? = nil

    func bringToFront(playerId: String) {
        activePlayerId = playerId
    }

    func zIndexForPlayer(_ playerId: String) -> Double {
        if playerId == activePlayerId {
            return 1000
        }
        return 0 
    }
    
    // MARK: - Dependencies

    private let firebase = FirebaseService.shared
    private weak var session: GameSession?

    private var challengeListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?

    private var syncTimerCancellable: AnyCancellable?
    private var appForegroundCancellable: AnyCancellable?
    private var lastUploadedSteps: Int? = nil

    // MARK: - Popup Gating

    private var warmupUntil: Date? = nil
    private var lastPopupShown: MapPopupType? = nil
    private var lastPopupShownAt: Date? = nil

    private var isWarmupActive: Bool {
        if let until = warmupUntil {
            return Date() < until
        }
        return false
    }

    private var maxStepsAcrossParticipants: Int {
        participants.map(\.steps).max() ?? 0
    }

    private var areStepsMeaningful: Bool {
        maxStepsAcrossParticipants > 0
    }

   var leadingPlayerName: String {
        guard let leader = leadingParticipant() else { return "Leader" }
        let myId = session?.uid ?? ""
        if leader.playerId == myId {
            return "You"
        }
        return playersById[leader.playerId]?.name ?? "Leader"
    }
    
    private func shouldAllowPuzzlePopups(
        checkSteps: Bool = true,
        now: Date = Date()
    ) -> Bool {
        if isChallengeEnded { return false }
        if isWarmupActive { return false }
        if checkSteps && !areStepsMeaningful { return false }
        if pendingMapPopup != nil { return false }
        return true
    }

    private func tryPresentPopup(
        _ popup: MapPopupType,
        cooldownSeconds: TimeInterval = 60,
        now: Date = Date()
    ) {
        if pendingMapPopup != nil { return }

        if lastPopupShown == popup,
           let t = lastPopupShownAt,
           now.timeIntervalSince(t) < cooldownSeconds {
            return
        }

        lastPopupShown = popup
        lastPopupShownAt = now
        pendingMapPopup = popup
    }

    // MARK: - Lifecycle

    deinit {
        MainActor.assumeIsolated {
            unbind()
            stopStepsSync()
        }
        syncTimerCancellable?.cancel()
        appForegroundCancellable?.cancel()
    }

    // MARK: - Map Points

    private let pathPoints: [CGPoint] = [
        .init(x: 0.714, y: 0.867),
        .init(x: 0.705, y: 0.746),
        .init(x: 0.596, y: 0.660),
        .init(x: 0.696, y: 0.594),
        .init(x: 0.554, y: 0.509),
        .init(x: 0.670, y: 0.433),
        .init(x: 0.546, y: 0.357),
        .init(x: 0.690, y: 0.293),
        .init(x: 0.573, y: 0.199),
        .init(x: 0.693, y: 0.121),
        .init(x: 0.770, y: 0.053),
    ]

    private let flagAnchors: [CGPoint] = [
        .init(x: 0.604, y: 0.847),
        .init(x: 0.595, y: 0.726),
        .init(x: 0.486, y: 0.640),
        .init(x: 0.586, y: 0.574),
        .init(x: 0.444, y: 0.489),
        .init(x: 0.560, y: 0.413),
        .init(x: 0.436, y: 0.337),
        .init(x: 0.580, y: 0.273),
        .init(x: 0.463, y: 0.179),
        .init(x: 0.583, y: 0.101),
    ]

    var isChallengeEnded: Bool {
        guard let ch = challenge else { return false }
        return ch.status == .ended || Date() >= ch.effectiveEndDate
    }

    private lazy var flagProgressesOnPath: [CGFloat] = {
        computeFlagProgressesOnPath()
    }()

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func mappedProgressForSteps(_ steps: Int, goalSteps: Int) -> CGFloat {
        let goal = max(goalSteps, 1)

        let ms = makeMilestones(goalSteps: goal, count: flagAnchors.count, unit: 100)
        let fp = flagProgressesOnPath
        guard ms.count == fp.count, !ms.isEmpty else {
            return min(max(CGFloat(steps) / CGFloat(goal), 0), 1)
        }

        if steps <= 0 { return 0 }

        if steps < ms[0] {
            let t = CGFloat(steps) / CGFloat(ms[0])
            return lerp(0, fp[0], t)
        }

        for i in 1..<ms.count {
            let prevM = ms[i - 1]
            let nextM = ms[i]

            if steps < nextM {
                let denom = max(nextM - prevM, 1)
                var local = CGFloat(steps - prevM) / CGFloat(denom)
                local = min(max(local, 0), 0.999)
                return lerp(fp[i - 1], fp[i], local)
            }
        }

        return 1
    }

    private func computeFlagProgressesOnPath() -> [CGFloat] {
        let pts = pathPoints
        guard pts.count >= 2 else { return Array(repeating: 0, count: flagAnchors.count) }

        var segLens: [CGFloat] = []
        segLens.reserveCapacity(pts.count - 1)

        var cum: [CGFloat] = [0]
        cum.reserveCapacity(pts.count)

        var total: CGFloat = 0
        for i in 0..<(pts.count - 1) {
            let d = hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)
            segLens.append(d)
            total += d
            cum.append(total)
        }
        if total <= 0 { return Array(repeating: 0, count: flagAnchors.count) }

        func closestProgress(to p: CGPoint) -> CGFloat {
            var bestDist = CGFloat.greatestFiniteMagnitude
            var bestAlong: CGFloat = 0

            for i in 0..<(pts.count - 1) {
                let a = pts[i]
                let b = pts[i + 1]
                let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
                let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)

                let ab2 = ab.x * ab.x + ab.y * ab.y
                if ab2 == 0 { continue }

                var t = (ap.x * ab.x + ap.y * ab.y) / ab2
                t = min(max(t, 0), 1)

                let proj = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
                let dist = hypot(proj.x - p.x, proj.y - p.y)

                if dist < bestDist {
                    bestDist = dist
                    bestAlong = cum[i] + segLens[i] * t
                }
            }

            return bestAlong / total
        }

        return flagAnchors.map { closestProgress(to: $0) }
    }

    // MARK: - Bind / Unbind

    func bind(session: GameSession) {
        self.session = session
        unbind()

        participants = []
        myParticipant = nil
        playersById = [:]
        resultPopupVM = nil
        isShowingResultPopup = false
        pendingMapPopup = nil

        lastPopupShown = nil
        lastPopupShownAt = nil
        warmupUntil = nil

        challenge = session.challenge
        lastUploadedSteps = nil

        if isChallengeEnded {
            stopStepsSync()
        }

        rebuildAllUI()
        evaluateResultPopupIfNeeded()
        maybeEndChallengeIfNeeded()

        guard let chId = session.challenge?.id else { return }

        challengeListener = firebase.listenChallenge(challengeId: chId) { [weak self] updated in
            guard let self else { return }
            Task { @MainActor in
                self.challenge = updated
                self.session?.challenge = updated

                if self.isChallengeEnded {
                    self.stopStepsSync()
                }

                self.rebuildAllUI()
                self.evaluateResultPopupIfNeeded()
                self.maybeEndChallengeIfNeeded()

                self.evaluateSoloLate()
                self.evaluateGroupAttack()
                self.evaluateGroupDefender()
            }
        }

        participantsListener = firebase.listenParticipants(challengeId: chId) { [weak self] list in
            guard let self else { return }
            Task { @MainActor in
                self.participants = list
                self.recomputeMyParticipant()
                await self.fetchPlayersIfNeeded()
                self.rebuildAllUI()
                self.evaluateResultPopupIfNeeded()
                self.maybeEndChallengeIfNeeded()

                self.evaluateSoloLate()
                self.evaluateGroupAttack()
                self.evaluateGroupDefender()
            }
        }
    }

    func unbind() {
        challengeListener?.remove()
        challengeListener = nil
        participantsListener?.remove()
        participantsListener = nil
    }

    private func recomputeMyParticipant() {
        let myId = session?.uid ?? session?.player?.id ?? ""
        myParticipant = participants.first(where: { $0.playerId == myId })
    }

    private func fetchPlayersIfNeeded() async {
        let ids = participants.map { $0.playerId }
        let missing = ids.filter { playersById[$0] == nil }
        guard !missing.isEmpty else { return }

        do {
            let fetched = try await firebase.fetchPlayers(uids: missing)
            var dict = playersById
            for p in fetched {
                if let id = p.id { dict[id] = p }
            }
            playersById = dict
        } catch { }
    }

    // MARK: - Feature Triggers

    func evaluateSoloLate(now: Date = Date()) {
        guard shouldAllowPuzzlePopups(checkSteps: false, now: now) else { return }
        guard let ch = challenge else { return }
        guard isEffectivelySolo else { return }
        guard let myPart = myParticipant else { return }

        /// Don't show popup in first 3 hours of challenge
        if let startedAt = ch.startedAt ?? ch.startDate as Date? {
            let hoursElapsed = now.timeIntervalSince(startedAt) / 3600
            guard hoursElapsed >= 3 else { return }
        }

        if isLockedToday(myPart.soloAttemptedAt, now: now) { return }
        if isCooldownActive(myPart.soloDismissedAt, seconds: dismissCooldown, now: now) { return }

        let expected = expectedProgressByTime(challenge: ch, now: now)
        let actual = CGFloat(myPart.steps) / CGFloat(max(ch.goalSteps, 1))

        guard actual < expected else { return }
        tryPresentPopup(.soloLate, cooldownSeconds: 2 * 60 * 60, now: now)
    }

    func evaluateGroupDefender(now: Date = Date()) {
        guard let myPart = myParticipant else { return }

        /// Don't show popup in first 3 hours of challenge
        if let ch = challenge, let startedAt = ch.startedAt ?? ch.startDate as Date? {
            let hoursElapsed = now.timeIntervalSince(startedAt) / 3600
            guard hoursElapsed >= 3 else { return }
        }

        if isLockedToday(myPart.groupDefenseAttemptedAt, now: now) { return }
        if isCooldownActive(myPart.groupDefenseDismissedAt, seconds: dismissCooldown, now: now) { return }

        if let exp = myPart.sabotageExpiresAt, now < exp {
            if !isWarmupActive, pendingMapPopup == nil {
                tryPresentPopup(.groupDefender, cooldownSeconds: 2 * 60 * 60, now: now)
            }
        }
    }

    func evaluateGroupAttack(now: Date = Date()) {
        guard shouldAllowPuzzlePopups(checkSteps: false, now: now) else { return }
        guard isGroupChallenge else { return }
        guard let myPart = myParticipant else { return }

        if let ch = challenge, let startedAt = ch.startedAt ?? ch.startDate as Date? {
            let hoursElapsed = now.timeIntervalSince(startedAt) / 3600
            guard hoursElapsed >= 3 else { return }
        }

        if isLockedToday(myPart.groupAttackAttemptedAt, now: now) { return }
        if isCooldownActive(myPart.groupAttackDismissedAt, seconds: dismissCooldown, now: now) { return }

        guard let last = lastParticipant(),
              let leader = leadingParticipant() else { return }

        guard last.playerId == myPart.playerId else { return }
        guard leader.playerId != myPart.playerId else { return }

        let stepsDifference = leader.steps - myPart.steps
        guard stepsDifference > 0 else { return }

        if let exp = leader.sabotageExpiresAt, now < exp { return }

        guard let ch = challenge else { return }
        
        let leaderState = computedCharacterState(
            challenge: ch,
            participant: leader,
            now: now
        )
        
        guard leaderState != .lazy else {
            return
        }

        tryPresentPopup(.groupAttacker, cooldownSeconds: 2 * 60 * 60, now: now)
    }
    
    // MARK: - UI Builders

    private func rebuildAllUI() {
        guard let session else { return }
        guard let ch = challenge else { return }
        
        let myId = session.uid ?? session.player?.id ?? ""
        let now = Date()
        
        let vms: [MapPlayerVM] = participants.map { part in
            let isMe = (part.playerId == myId)
            let p = isMe ? session.player : playersById[part.playerId]
            let type = p?.characterType ?? .character1
            
            let name = p?.name ?? (isMe ? "Me" : shortId(part.playerId))
            let hudAvatar = type.avatarKey()
            
            let mapped = mappedProgressForSteps(part.steps, goalSteps: ch.goalSteps)
            let progress = Double(mapped)
            
            let isUnderSabotage: Bool = {
                guard let exp = part.sabotageExpiresAt else { return false }
                return now < exp
            }()
            
            let attackerId = part.sabotageByPlayerId
            
            let isAttackedByMe = {
                guard isUnderSabotage else { return false }
                guard let attackerId else { return false }
                return attackerId == myId
            }()
            
            let attackedByName: String? = {
                guard isUnderSabotage, let attackerId else { return nil }
                if attackerId == myId { return "You" }
                return playersById[attackerId]?.name ?? shortId(attackerId)
            }()
            
            let state = computedCharacterState(challenge: ch, participant: part)
            let mapSprite = type.imageKey(state: state)
            
            // Check if player left
            let hasLeft = part.leftAt != nil
            
            return MapPlayerVM(
                id: part.playerId,
                name: name,
                hudAvatar: hudAvatar,
                mapSprite: mapSprite,
                steps: part.steps,
                progress: progress,
                isMe: isMe,
                place: part.place,
                attackedByName: attackedByName,
                isUnderSabotage: isUnderSabotage,
                sabotageExpiresAt: part.sabotageExpiresAt,
                isAttackedByMe: isAttackedByMe,
                lastSyncedAt: part.lastSyncedAt,
                isChallengeEnded: isChallengeEnded,
                hasLeft: hasLeft,
                leftAt: part.leftAt
            )
        }
        
        mapPlayers = vms.sorted { a, b in
            if a.isMe != b.isMe { return a.isMe }
            if a.hasLeft != b.hasLeft { return !a.hasLeft }  // Active players first
            return a.steps > b.steps
        }
        
        let me = mapPlayers.first(where: { $0.isMe })
        
        let friend: MapPlayerVM? = {
            let others = mapPlayers.filter { !$0.isMe }
            guard !others.isEmpty, let me = mapPlayers.first(where: { $0.isMe }) else {
                return others.first
            }
            
            return others.min(by: { player1, player2 in
                let diff1 = abs(me.steps - player1.steps)
                let diff2 = abs(me.steps - player2.steps)
                return diff1 < diff2
            })
        }()

        guard let me else { return }

        let userImage = me.mapSprite
        let friendImage = friend?.mapSprite ?? "character2_normal"
        
        WidgetStore.save(
            challengeName: ch.name,
            userName: me.name,
            userSteps: me.steps,
            userGoal: ch.goalSteps,
            userImage: userImage,
            friendName: friend?.name ?? "Friend",
            friendSteps: friend?.steps ?? 0,
            friendGoal: ch.goalSteps,
            friendImage: friendImage,
            isSoloChallenge: ch.currentMode.rawValue,
            startDate: (ch.startedAt ?? ch.startDate),
            durationDays: ch.durationDays
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Helpers

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    private func isLockedToday(_ date: Date?, now: Date) -> Bool {
        guard let date else { return false }
        return isSameDay(date, now)
    }

    private func isCooldownActive(_ date: Date?, seconds: TimeInterval, now: Date) -> Bool {
        guard let date else { return false }
        return now.timeIntervalSince(date) < seconds
    }

    private let dismissCooldown: TimeInterval = 2 * 60 * 60
    
    var titleText: String { challenge?.name ?? "" }

    var isGroupChallenge: Bool {
        guard let ch = challenge else { return false }
        return (ch.originalMode == .social && ch.maxPlayers > 1)
    }

    var hudAvatars: [String] {
        guard isGroupChallenge else { return [] }
        return mapPlayers
            .filter { !$0.hasLeft } 
            .map { $0.hudAvatar }
    }

    var myHudAvatar: String {
        if let me = mapPlayers.first(where: { $0.isMe }) { return me.hudAvatar }
        return (session?.player?.characterType.avatarKey() ?? "character1_avatar")
    }

    var mySteps: Int {
        mapPlayers.first(where: { $0.isMe })?.steps ?? 0
    }

    var stepsLeftText: String {
        guard let ch = challenge else { return "0 Steps Left" }
        let left = max(0, ch.goalSteps - mySteps)
        return "\(left.formatted()) Steps Left"
    }

    var daysLeftText: String {
        guard let ch = challenge else { return "0 Days Left" }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let endDayStart = cal.startOfDay(for: ch.effectiveEndDate)

        let diff = cal.dateComponents([.day], from: todayStart, to: endDayStart).day ?? 0
        let daysLeft = max(0, diff)

        let dayWord = daysLeft == 1 ? "Day" : "Days"
        return "\(daysLeft) \(dayWord) Left"
    }


    var durationText: String {
        guard let ch = challenge else { return "0 Days" }
        let days = ch.durationDays
        let dayWord = days == 1 ? "Day" : "Days"
        return "\(days) \(dayWord)"
    }
    
    var goalSteps: Int {
        challenge?.goalSteps ?? 0
    }

    func positionForPlayer(_ player: MapPlayerVM, mapSize: CGSize) -> CGPoint {
        let base = positionForProgress(progress: CGFloat(player.progress), mapSize: mapSize)

        // Group players with similar progress
        let grouped = mapPlayers
            .sorted { $0.id < $1.id }
            .filter { abs($0.progress - player.progress) < 0.01 }

        guard grouped.count > 1,
              let idx = grouped.firstIndex(where: { $0.id == player.id }) else {
            return clampToBounds(base, mapSize: mapSize)
        }

        let count = grouped.count
        let spacing: CGFloat = 78 // Horizontal spacing between players

        // Calculate offset from center (side by side arrangement)
        let totalWidth = CGFloat(count - 1) * spacing
        let startX = -totalWidth / 2
        let offsetX = startX + CGFloat(idx) * spacing

        let shifted = CGPoint(
            x: base.x + offsetX,
            y: base.y  // Keep same Y position (players side by side)
        )

        return clampToBounds(shifted, mapSize: mapSize)
    }

    private func clampToBounds(_ point: CGPoint, mapSize: CGSize) -> CGPoint {
        let bubbleWidth: CGFloat = 60
        let spriteWidth: CGFloat = 85

        let paddingX: CGFloat = max(bubbleWidth, spriteWidth) / 2 + 12
        let paddingY: CGFloat = spriteWidth / 2 + 10

        let minX = paddingX
        let maxX = mapSize.width - paddingX
        let minY = paddingY
        let maxY = mapSize.height - paddingY

        return CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }

    var milestones: [Int] {
        guard let ch = challenge else { return [] }
        return makeMilestones(goalSteps: ch.goalSteps, count: flagAnchors.count, unit: 100)
    }

    func isFlagReached(_ milestone: Int) -> Bool { mySteps >= milestone }

    func flagPosition(index: Int, mapSize: CGSize) -> CGPoint {
        let a = flagAnchors[index]
        return CGPoint(x: mapSize.width * a.x, y: mapSize.height * a.y)
    }

    // MARK: - Steps Sync

    func startStepsSync(health: HealthKitManager) {
        stopStepsSync()
        if isChallengeEnded { return }

        Task { await syncOnce(health: health) }

        syncTimerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.syncOnce(health: health) }
            }

        appForegroundCancellable = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.syncOnce(health: health) }
            }
    }

    func stopStepsSync() {
        syncTimerCancellable?.cancel()
        syncTimerCancellable = nil
        appForegroundCancellable?.cancel()
        appForegroundCancellable = nil
    }

    private func syncOnce(health: HealthKitManager) async {
        guard let session else { return }
        guard let ch = session.challenge, let chId = ch.id else { return }
        guard let uid = session.uid else { return }
        guard health.isAuthorized else { return }

        if let me = myParticipant, me.leftAt != nil {
            stopStepsSync()
            return
        }

        if isChallengeEnded || ch.status != .active {
            stopStepsSync()
            return
        }

        let now = Date()

        let startRaw = ch.startedAt ?? ch.startDate
        let startDay = Calendar.current.startOfDay(for: startRaw)

        let endDay = Calendar.current.date(byAdding: .day, value: ch.durationDays, to: startDay)
            ?? startDay.addingTimeInterval(TimeInterval(ch.durationDays * 86400))

        let end = min(now, endDay)

        do {
            let stepsTotal = try await health.fetchSteps(from: startDay, to: end)
            if lastUploadedSteps == stepsTotal { return }

            let goal = max(ch.goalSteps, 1)
            let progress = min(max(Double(stepsTotal) / Double(goal), 0), 1)
            let state: CharacterState = (progress >= 1) ? .active : .normal

            try await firebase.updateParticipantSteps(
                challengeId: chId,
                uid: uid,
                steps: stepsTotal,
                progress: progress,
                characterState: state
            )

            lastUploadedSteps = stepsTotal

            if stepsTotal >= goal {
                try? await firebase.tryMarkFinishedAndClaimWinnerIfNeeded(
                    challengeId: chId,
                    uid: uid,
                    now: now
                )
            }

            if now >= endDay {
                stopStepsSync()
            }
        } catch { }
    }

    // MARK: - Result Popup

    private func evaluateResultPopupIfNeeded(now: Date = Date()) {
        guard !isShowingResultPopup else { return }
        guard let ch = challenge, let chId = ch.id else { return }
        guard let me = session?.player else { return }
        guard let myPart = myParticipant else { return }
        if myPart.challengeId != chId { return }

        let iFinished = (myPart.finishedAt != nil)
        let timeEnded = (now >= ch.effectiveEndDate)
        guard iFinished || timeEnded else { return }

        resultPopupVM = ChallengeResultPopupViewModel(
            challenge: ch,
            me: me,
            myParticipant: myPart,
            participants: participants,
            playersById: playersById
        )
        isShowingResultPopup = true
    }

    func dismissResultPopup() {
        isShowingResultPopup = false
        resultPopupVM = nil
    }

    // MARK: - Character State

    private func computedCharacterState(
        challenge: Challenge,
        participant: ChallengeParticipant,
        now: Date = Date()
    ) -> CharacterState {

        if let exp = participant.sabotageExpiresAt,
           now < exp,
           let s = participant.sabotageState {
            return s
        }

        let goal = max(challenge.goalSteps, 1)

        let stepsProgress = CGFloat(participant.steps) / CGFloat(goal)
        let expected = expectedProgressByTime(challenge: challenge, now: now)
        let diff = stepsProgress - expected

        let activeThreshold: CGFloat = 0.10
        let lazyThreshold: CGFloat = -0.10

        if diff >= activeThreshold { return .active }
        if diff <= lazyThreshold { return .lazy }
        return .normal
    }

    private func expectedProgressByTime(challenge: Challenge, now: Date = Date()) -> CGFloat {
        let start = challenge.startedAt ?? challenge.startDate
        let end = challenge.effectiveEndDate

        let total = end.timeIntervalSince(start)
        if total <= 0 { return 1 }

        let elapsed = now.timeIntervalSince(start)
        let p = elapsed / total
        return min(max(CGFloat(p), 0), 1)
    }

    private func positionForProgress(progress: CGFloat, mapSize: CGSize) -> CGPoint {
        guard pathPoints.count >= 2 else { return .zero }

        let clamped = min(max(progress, 0), 1)
        let maxIndex = pathPoints.count - 1

        let exactIndex = clamped * CGFloat(maxIndex)
        let lowerIndex = Int(floor(exactIndex))
        let upperIndex = min(lowerIndex + 1, maxIndex)

        let t = exactIndex - CGFloat(lowerIndex)

        let p1 = pathPoints[lowerIndex]
        let p2 = pathPoints[upperIndex]

        let xNorm = p1.x + (p2.x - p1.x) * t
        let yNorm = p1.y + (p2.y - p1.y) * t

        return CGPoint(x: xNorm * mapSize.width, y: yNorm * mapSize.height)
    }

    // MARK: - Challenge End

    private func maybeEndChallengeIfNeeded(now: Date = Date()) {
        guard let ch = challenge, let chId = ch.id else { return }
        guard ch.status != .ended else { return }

        let timeEnded = (now >= ch.effectiveEndDate)
        let allFinished = !participants.isEmpty && participants.allSatisfy { $0.finishedAt != nil }

        guard timeEnded || allFinished else { return }

        Task { try? await firebase.markChallengeEnded(challengeId: chId, now: now) }
    }

    // MARK: - Milestones

    private func makeMilestones(goalSteps: Int, count: Int, unit: Int) -> [Int] {
        guard count > 0 else { return [] }

        let goal = max(goalSteps, unit)
        let rawStep = Double(goal) / Double(count)

        var ms: [Int] = []
        for i in 1...count {
            let rawValue = Double(i) * rawStep
            let roundedUp = Int(ceil(rawValue / Double(unit))) * unit
            ms.append(roundedUp)
        }

        for i in 1..<ms.count where ms[i] <= ms[i - 1] {
            ms[i] = ms[i - 1] + unit
        }

        if let last = ms.last, last < goal {
            ms[ms.count - 1] = Int(ceil(Double(goal) / Double(unit))) * unit
        }

        return ms
    }

    private func shortId(_ id: String) -> String {
        if id.count <= 6 { return id }
        return "\(id.prefix(3))...\(id.suffix(3))"
    }

    // MARK: - Group Helpers

    func leadingParticipant() -> ChallengeParticipant? {
        guard isGroupChallenge else { return nil }
        return participants
            .filter { $0.leftAt == nil }
            .max(by: { $0.steps < $1.steps })
    }

    private func lastParticipant() -> ChallengeParticipant? {
        participants
            .filter { $0.leftAt == nil }
            .min(by: { $0.steps < $1.steps })
    }

    var leadingPlayerId: String? {
        participants
            .filter { $0.leftAt == nil }
            .max(by: { $0.steps < $1.steps })?
            .playerId
    }
    
    private var isEffectivelySolo: Bool {
        guard let ch = challenge else { return false }
        if ch.originalMode == .solo { return true }
        
        let activePlayers = participants.filter { $0.leftAt == nil }
        return ch.originalMode == .social && activePlayers.count <= 1
    }
}
