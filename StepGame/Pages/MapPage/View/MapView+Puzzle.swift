//
//  MapView+Puzzle.swift
//  StepGame
//

import SwiftUI

extension MapView {

    // MARK: - Helpers

    func showChallengesSheet() {
        selectedDetent = .height(90)
        activeSheet = .challenges
    }

    func dismissSheetAndPopups() {
        activeSheet = nil
        activeMapPopup = nil
    }

    // MARK: - Puzzle Launchers

   func recordDismiss(for popup: MapPopupType) {
        guard let chId = session.challenge?.id, let uid = session.uid else { return }

        let kind: FirebaseService.PuzzleAttemptKind
        switch popup {
        case .soloLate: kind = .solo
        case .groupAttacker: kind = .groupAttack
        case .groupDefender: kind = .groupDefense
        }

        Task { try? await FirebaseService.shared.markPuzzleDismissed(challengeId: chId, uid: uid, kind: kind) }
    }
    
    func startSoloGameSafely() {
        guard connectivity.isOnline else { return }
        dismissSheetAndPopups()

        guard let chId = session.challenge?.id, let uid = session.uid else { return }
        Task {
            try? await FirebaseService.shared.markPuzzleAttempted(challengeId: chId, uid: uid, kind: .solo)
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    activePuzzle = .soloExtension
                }
            }
        }
    }

    func startAttackerGameSafely() {
        guard connectivity.isOnline else { return }
        dismissSheetAndPopups()

        guard let chId = session.challenge?.id, let uid = session.uid else { return }
        Task {
            try? await FirebaseService.shared.markPuzzleAttempted(challengeId: chId, uid: uid, kind: .groupAttack)
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    activePuzzle = .groupAttack
                }
            }
        }
    }

    func startDefenderGameSafely() {
        guard connectivity.isOnline else { return }
        dismissSheetAndPopups()

        guard let chId = session.challenge?.id, let uid = session.uid else { return }
        Task {
            try? await FirebaseService.shared.markPuzzleAttempted(challengeId: chId, uid: uid, kind: .groupDefense)
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    activePuzzle = .groupDefense
                }
            }
        }
    }

    // MARK: - Puzzle Finish

    func handlePuzzleFinish(
        req: PuzzleRequest,
        success: Bool,
        time: Double,
        didTimeout: Bool
    ) async {

        guard let chId = session.challenge?.id else { return }
        guard let myId = session.uid else { return }

        switch req {

        case .soloExtension:
            if success {
                do {
                    try await FirebaseService.shared.addOneDayExtension(challengeId: chId)
                } catch {
                    print("addOneDayExtension failed:", error.localizedDescription)
                }

                puzzleResult = PuzzleResult(
                    context: .solo,
                    success: true,
                    myTime: time,
                    opponentTime: nil,
                    reason: .solved,
                    title: "Awesome!",
                    message: "+1 day extension added!"
                )
            } else {
                do {
                    try await FirebaseService.shared.markSoloPuzzleFailed(challengeId: chId, uid: myId)
                } catch {
                    print("markSoloPuzzleFailed failed:", error.localizedDescription)
                }

                puzzleResult = PuzzleResult(
                    context: .solo,
                    success: false,
                    myTime: time,
                    opponentTime: nil,
                    reason: didTimeout ? .timeOut : .notSolved,
                    title: "Oops!",
                    message: didTimeout ? "Time is up" : "You didn’t solve the wiring"
                )
            }

        case .groupAttack:
            guard let targetId = vm.leadingPlayerId, targetId != myId else {
                puzzleResult = PuzzleResult(
                    context: .groupAttack,
                    success: false,
                    myTime: time,
                    opponentTime: nil,
                    reason: .notSolved,
                    title: "Attack Failed",
                    message: "Couldn't find a valid target"
                )
                return
            }

            if success {
                do {
                    try await FirebaseService.shared.applyGroupAttack(
                        challengeId: chId,
                        targetId: targetId,
                        attackerId: myId,
                        attackTimeSeconds: time
                    )
                    try await FirebaseService.shared.markGroupAttackSucceeded(challengeId: chId, uid: myId)
                } catch {
                    print("applyGroupAttack failed:", error.localizedDescription)
                }

                puzzleResult = PuzzleResult(
                    context: .groupAttack,
                    success: true,
                    myTime: time,
                    opponentTime: nil,
                    reason: .solved,
                    title: "Attack Succeeded!",
                    message: "You sabotaged your friend for 3 hours"
                )
            } else {
                do {
                    try await FirebaseService.shared.markGroupAttackPuzzleFailed(challengeId: chId, uid: myId)
                } catch {
                    print("markGroupAttackPuzzleFailed failed:", error.localizedDescription)
                }

                puzzleResult = PuzzleResult(
                    context: .groupAttack,
                    success: false,
                    myTime: time,
                    opponentTime: nil,
                    reason: didTimeout ? .timeOut : .notSolved,
                    title: "Oops!",
                    message: didTimeout ? "Time is up" : "You didn’t solve the wiring"
                )
            }

        case .groupDefense:
            let oppTime = vm.myParticipant?.sabotageAttackTimeSeconds
            let attackerId = vm.myParticipant?.sabotageByPlayerId

            if attackerId == nil {
                puzzleResult = PuzzleResult(
                    context: .groupDefense,
                    success: success,
                    myTime: time,
                    opponentTime: nil,
                    reason: success ? .solved : (didTimeout ? .timeOut : .notSolved),
                    title: success ? "Defended!" : "Defense Failed",
                    message: success ? "No active sabotage to defend" : (didTimeout ? "Time is up" : "You didn’t solve the wiring")
                )
                return
            }

            if !success {
                puzzleResult = PuzzleResult(
                    context: .groupDefense,
                    success: false,
                    myTime: time,
                    opponentTime: oppTime,
                    reason: didTimeout ? .timeOut : .notSolved,
                    title: "Defense Failed",
                    message: didTimeout ? "Time is up" : "You didn’t solve the wiring"
                )
                return
            }

            if let opp = oppTime {
                if time <= opp {
                    do {
                        try await FirebaseService.shared.cancelGroupAttack(challengeId: chId, targetId: myId)
                    } catch {
                        print("cancelGroupAttack failed:", error.localizedDescription)
                    }

                    puzzleResult = PuzzleResult(
                        context: .groupDefense,
                        success: true,
                        myTime: time,
                        opponentTime: opp,
                        reason: .solved,
                        title: "Awesome!",
                        message: "You were faster than the attacker. Sabotage removed!"
                    )
                } else {
                    puzzleResult = PuzzleResult(
                        context: .groupDefense,
                        success: false,
                        myTime: time,
                        opponentTime: opp,
                        reason: .slowerThanOpponent(myTime: time, opponentTime: opp),
                        title: "Oops!",
                        message: "You solved it, but the attacker was faster"
                    )
                }
            } else {
                do {
                    try await FirebaseService.shared.cancelGroupAttack(challengeId: chId, targetId: myId)
                } catch {
                    print("cancelGroupAttack failed:", error.localizedDescription)
                }

                puzzleResult = PuzzleResult(
                    context: .groupDefense,
                    success: true,
                    myTime: time,
                    opponentTime: nil,
                    reason: .solved,
                    title: "Awesome!",
                    message: "Sabotage removed!"
                )
            }
        }
    }
}
