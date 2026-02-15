//
//  PuzzleContext.swift
//  StepGame
//
//

import Foundation

enum PuzzleContext {
    case soloExtension
    case groupAttack
    case groupDefense
}

import SwiftUI

struct QuickPuzzleView: View {

    let context: PuzzleContext
    let onFinish: (_ success: Bool, _ timeSeconds: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var seconds: Double = 0
    @State private var timer: Timer?

    private var title: String {
        switch context {
        case .soloExtension: return "Solo Puzzle"
        case .groupAttack: return "Attack Puzzle"
        case .groupDefense: return "Defense Puzzle"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(title)
                    .font(.custom("RussoOne-Regular", size: 28))
                    .foregroundStyle(.white)

                Text("Time: \(seconds, specifier: "%.1f")s")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()

                Text("✅ مؤقت للتجربة\nبعدها نستبدله بالبزل الحقيقي")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 14) {
                    Button { finish(true) } label: {
                        Text("WIN ✅")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 140, height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.green.opacity(0.75)))
                    }

                    Button { finish(false) } label: {
                        Text("LOSE ❌")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 140, height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.red.opacity(0.75)))
                    }
                }

                Button("Close") { dismiss() }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            start = Date()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                seconds = Date().timeIntervalSince(start)
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func finish(_ success: Bool) {
        let t = Date().timeIntervalSince(start)
        onFinish(success, t)
        dismiss()
    }
}
