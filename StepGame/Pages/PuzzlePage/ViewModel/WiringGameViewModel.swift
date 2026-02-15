//
//  WiringGameViewModel.swift
//  StepGame
//
//  Created by Arwa Alkadi on 12/02/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Puzzle Types
enum PuzzleRequest: Identifiable {
    case soloExtension
    case groupAttack
    case groupDefense

    var id: Int { hashValue }
}

enum PuzzleContext: String, Codable {
    case solo
    case groupAttack
    case groupDefense
}

enum MapPopupType: Identifiable {
    case soloLate
    case groupAttacker
    case groupDefender

    var id: Int { hashValue }
}

// MARK: - Puzzle Result
enum PuzzleEndReason: Equatable {
    case solved
    case timeOut
    case notSolved
    case slowerThanOpponent(myTime: Double, opponentTime: Double)
    case opponentDidNotPlay
}

struct PuzzleResult: Identifiable {
    let id = UUID()

    let context: PuzzleContext
    let success: Bool

    let myTime: Double
    let opponentTime: Double?

    let reason: PuzzleEndReason
    let title: String
    let message: String
}

// MARK: - Wire Types
struct WireColor: Identifiable, Equatable {
    let id = UUID()
    let color: Color
    let name: String

    static let red = WireColor(color: .red, name: "red")
    static let blue = WireColor(color: .blue, name: "blue")
    static let yellow = WireColor(color: .yellow, name: "yellow")
    static let pink = WireColor(color: Color(red: 1.0, green: 0.0, blue: 1.0), name: "pink")
    static let green = WireColor(color: .green, name: "green")

    static func == (lhs: WireColor, rhs: WireColor) -> Bool {
        lhs.name == rhs.name
    }
}

struct WiringCircle: Identifiable {
    let id = UUID()
    let color: Color
    let position: CGPoint
    let pairId: Int
}

struct WiringLine: Identifiable {
    let id = UUID()
    let color: Color
    let startPoint: CGPoint
    var endPoint: CGPoint
    let startCircleId: UUID
    var endCircleId: UUID?
    let pairId: Int
}

// MARK: - Wiring Game State

final class WiringGameState: ObservableObject {

    @Published var circles: [WiringCircle] = []
    @Published var lines: [WiringLine] = []
    @Published var currentLine: WiringLine?

    var onWin: (() -> Void)?

    private var dragStartCircle: WiringCircle?
    private let circleRadius: CGFloat = 25

    init() {
        setupGame()
    }

    /// Generates a new board and randomizes the right column order.
    func setupGame() {
        let colors: [Color] = [
            WireColor.red.color,
            WireColor.green.color,
            WireColor.blue.color,
            WireColor.yellow.color,
            WireColor.pink.color
        ]

        let ys: [CGFloat] = [80, 170, 260, 350, 440]

        var left: [WiringCircle] = []
        for i in 0..<colors.count {
            left.append(
                WiringCircle(
                    color: colors[i],
                    position: CGPoint(x: 60, y: ys[i]),
                    pairId: i
                )
            )
        }

        let rightOrder = Array(0..<colors.count).shuffled()

        var right: [WiringCircle] = []
        for row in 0..<rightOrder.count {
            let pairId = rightOrder[row]
            right.append(
                WiringCircle(
                    color: colors[pairId],
                    position: CGPoint(x: 280, y: ys[row]),
                    pairId: pairId
                )
            )
        }

        circles = left + right
    }

    /// Returns whether the circle is the currently selected start circle.
    func isCircleActive(_ circle: WiringCircle) -> Bool {
        dragStartCircle?.id == circle.id
    }

    /// Updates the current gesture location.
    func handleDragChanged(location: CGPoint) {
        if dragStartCircle == nil {
            if let circle = findCircle(at: location) {
                dragStartCircle = circle
                lines.removeAll { $0.pairId == circle.pairId }

                currentLine = WiringLine(
                    color: circle.color,
                    startPoint: circle.position,
                    endPoint: location,
                    startCircleId: circle.id,
                    endCircleId: nil,
                    pairId: circle.pairId
                )
            }
        } else {
            if var line = currentLine {
                line.endPoint = location
                currentLine = line
            }
        }
    }

    /// Finalizes the connection if the user drops on a valid matching circle.
    func handleDragEnded(location: CGPoint) {
        guard let startCircle = dragStartCircle else { return }

        if let endCircle = findCircle(at: location) {
            if endCircle.pairId == startCircle.pairId, endCircle.id != startCircle.id {
                if var line = currentLine {
                    line.endPoint = endCircle.position
                    line.endCircleId = endCircle.id
                    lines.append(line)
                    checkWinCondition()
                }
            }
        }

        currentLine = nil
        dragStartCircle = nil
    }

    /// Resets the board and clears active state.
    func resetGame() {
        lines.removeAll()
        currentLine = nil
        dragStartCircle = nil
        setupGame()
    }

    private func findCircle(at location: CGPoint) -> WiringCircle? {
        circles.first { circle in
            let dx = circle.position.x - location.x
            let dy = circle.position.y - location.y
            return sqrt(dx * dx + dy * dy) <= circleRadius
        }
    }

    private func checkWinCondition() {
        let completed = lines.filter { $0.endCircleId != nil }
        if completed.count == 5 {
            onWin?()
        }
    }
}

// MARK: - Wiring Puzzle View Model
final class WiringGameViewModel: ObservableObject {

    @Published var isComplete = false
    @Published var hasFailed = false
    @Published var timeRemaining: Double = 8.0

    let gameState: WiringGameState

    private var timer: Timer?
    var timeLimit: Double

    init(timeLimit: Double = 8.0) {
        self.timeLimit = timeLimit
        self.gameState = WiringGameState()
        startTimer()

        gameState.onWin = { [weak self] in
            self?.isComplete = true
            self?.stopTimer()
        }
    }

    deinit {
        stopTimer()
    }

    private func startTimer() {
        timeRemaining = timeLimit
        hasFailed = false
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }

            if self.timeRemaining > 0, !self.isComplete {
                self.timeRemaining -= 0.1
            } else if self.timeRemaining <= 0, !self.isComplete {
                self.hasFailed = true
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
