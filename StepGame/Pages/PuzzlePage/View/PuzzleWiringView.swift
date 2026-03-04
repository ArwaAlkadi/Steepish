//
//  PuzzleWiringView.swift
//  StepGame
//

import SwiftUI

struct PuzzleWiringView: View {

    let timeLimit: Double
    let onCancel: () -> Void
    let onFinish: (_ success: Bool, _ timeSeconds: Double, _ didTimeout: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WiringGameViewModel
    @State private var didFinish = false

    init(
        timeLimit: Double = 8.0,
        onCancel: @escaping () -> Void,
        onFinish: @escaping (_ success: Bool, _ timeSeconds: Double, _ didTimeout: Bool) -> Void
    ) {
        self.timeLimit = timeLimit
        self.onCancel = onCancel
        self.onFinish = onFinish
        self._viewModel = StateObject(wrappedValue: WiringGameViewModel(timeLimit: timeLimit))
    }

    var body: some View {
        ZStack {
            Color.light3.ignoresSafeArea()

            VStack(spacing: 20) {
                header
                board
            }
        }
        .onChange(of: viewModel.isComplete) { completed in
            guard completed else { return }
            finish(success: true)
        }
        .onChange(of: viewModel.hasFailed) { failed in
            guard failed else { return }
            finish(success: false)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.light1)
                }
            }
            .padding(.horizontal)

            Text("Match the Wires!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color.light1)

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(viewModel.timeRemaining <= 3 ? Color.red1 : Color.light1)

                Text(String(format: "%.1f", max(0, viewModel.timeRemaining)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(viewModel.timeRemaining <= 3 ? Color.red1 : Color.light1)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.light4)
            .cornerRadius(10)
        }
    }

    // MARK: - Board

    private var board: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.light4)

            WiringBoardView(gameState: viewModel.gameState)
                .padding()
        }
        .padding(.horizontal, 18)
        .frame(height: 560)
    }

    // MARK: - Finish

    private func finish(success: Bool) {
        guard !didFinish else { return }
        didFinish = true

        let spent = max(0, timeLimit - viewModel.timeRemaining)
        let didTimeout = (!success && viewModel.timeRemaining <= 0.01)
        onFinish(success, spent, didTimeout)
        dismiss()
    }
}
// MARK: - Wiring Board View

struct WiringBoardView: View {
    @ObservedObject var gameState: WiringGameState

    var body: some View {
        GeometryReader { _ in
            ZStack {
                ForEach(gameState.lines) { line in
                    WavyLinePath(start: line.startPoint, end: line.endPoint)
                        .stroke(line.color, lineWidth: 10)
                        .opacity(0.85)
                }

                if let currentLine = gameState.currentLine {
                    WavyLinePath(start: currentLine.startPoint, end: currentLine.endPoint)
                        .stroke(currentLine.color, lineWidth: 10)
                        .opacity(0.6)
                }

                ForEach(gameState.circles) { circle in
                    WireNodeCircle(color: circle.color, isActive: gameState.isCircleActive(circle))
                        .position(circle.position)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        gameState.handleDragChanged(location: value.location)
                    }
                    .onEnded { value in
                        gameState.handleDragEnded(location: value.location)
                    }
            )
        }
    }
}

// MARK: - Wavy Line Path

struct WavyLinePath: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)

        let waveCount = max(1, Int(distance / 30))
        let amplitude: CGFloat = 30

        path.move(to: start)

        if distance > 0.001 {
            for i in 0...waveCount {
                let t = CGFloat(i) / CGFloat(waveCount)

                let straightX = start.x + dx * t
                let straightY = start.y + dy * t

                let perpX = -dy / distance
                let perpY = dx / distance

                let wave = sin(t * .pi * CGFloat(waveCount) * 2) * amplitude

                let controlPoint = CGPoint(
                    x: straightX + perpX * wave,
                    y: straightY + perpY * wave
                )

                if i == 0 {
                    path.move(to: start)
                } else if i == waveCount {
                    path.addQuadCurve(to: end, control: controlPoint)
                } else {
                    let nextT = CGFloat(i + 1) / CGFloat(waveCount)
                    let nextX = start.x + dx * nextT
                    let nextY = start.y + dy * nextT
                    let nextWave = sin(nextT * .pi * CGFloat(waveCount) * 2) * amplitude
                    let nextPoint = CGPoint(
                        x: nextX + perpX * nextWave,
                        y: nextY + perpY * nextWave
                    )
                    path.addQuadCurve(to: nextPoint, control: controlPoint)
                }
            }
        } else {
            path.addLine(to: end)
        }

        return path
    }
}

// MARK: - Wire Node Circle

struct WireNodeCircle: View {
    let color: Color
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 56, height: 56)

            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 70, height: 70)
                .blur(radius: 5)

            Circle()
                .fill(color)
                .frame(width: 50, height: 50)
        }
        .opacity(isActive ? 0.9 : 1.0)
    }
}


