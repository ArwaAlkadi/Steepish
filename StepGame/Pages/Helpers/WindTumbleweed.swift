//
//  WindTumbleweed.swift
//  StepGame
//
//

import SwiftUI

// MARK: - Single Wind
struct WindTumbleweed: View {

    let mapSize: CGSize

    var sizeRatio: CGFloat = 0.10
    var duration: Double = 60
    var spinSpeed: Double = 90

    var swayAmplitude: CGFloat = 18
    var swayWaves: CGFloat = 2.3

    var pathShiftY: CGFloat = 0.0
    var timeOffset: Double = 0.0

    var reversePath: Bool = false
    
    var loopPath: [CGPoint] = [
        .init(x: 0.12, y: 0.92),
        .init(x: 0.78, y: 0.80),
        .init(x: 0.22, y: 0.66),
        .init(x: 0.82, y: 0.52),
        .init(x: 0.28, y: 0.38),
        .init(x: 0.70, y: 0.20),
        .init(x: 0.55, y: 0.10),
        .init(x: 0.18, y: 0.18),
        .init(x: 0.62, y: 0.42),
        .init(x: 0.20, y: 0.60),
        .init(x: 0.72, y: 0.78),
        .init(x: 0.12, y: 0.92)
    ]

    @State private var startTime = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let elapsed = ctx.date.timeIntervalSince(startTime) + timeOffset
            let rawT = CGFloat((elapsed.truncatingRemainder(dividingBy: duration)) / duration)
            let t = reversePath ? (1 - rawT) : rawT

            let base = pointOnPath(t: t)
            let sway = sin(t * .pi * 2 * swayWaves) * swayAmplitude
            let spin = Angle.degrees(elapsed * spinSpeed)

            let size = mapSize.width * sizeRatio
            let final = CGPoint(x: base.x + sway, y: base.y)

            Image("Wind")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(spin)
                .position(final)
        }
        .onAppear { startTime = Date() }
    }

    // MARK: - Path Math
    private func pointOnPath(t: CGFloat) -> CGPoint {
        let pts = pathPixels
        guard pts.count >= 2 else { return .zero }

        let clamped = min(max(t, 0), 1)
        let segments = pts.count - 1
        let scaled = clamped * CGFloat(segments)

        let i = min(Int(floor(scaled)), segments - 1)
        let localT = scaled - CGFloat(i)

        let a = pts[i]
        let b = pts[i + 1]

        return CGPoint(
            x: a.x + (b.x - a.x) * localT,
            y: a.y + (b.y - a.y) * localT
        )
    }

    private var pathPixels: [CGPoint] {
        loopPath.map { p in
            let shiftedY = min(max(p.y + pathShiftY, 0.02), 0.98) // clamp
            return CGPoint(x: mapSize.width * p.x, y: mapSize.height * shiftedY)
        }
    }
}

// MARK: - Double Wind Layer
struct WindTumbleweedView: View {
    let mapSize: CGSize

    var body: some View {
        ZStack {
     
               
                WindTumbleweed(
                    mapSize: mapSize,
                    sizeRatio: 0.10,
                    duration: 100,
                    spinSpeed: 70,
                    swayAmplitude: 10,
                    swayWaves: 1.7,
                    pathShiftY: 0.28,
                    timeOffset: 0,
                    reversePath: false
                )

                WindTumbleweed(
                    mapSize: mapSize,
                    sizeRatio: 0.10,
                    duration: 100,
                    spinSpeed: 70,
                    swayAmplitude: 18,
                    swayWaves: 2.4,
                    pathShiftY: -0.28,
                    timeOffset: 25,
                    reversePath: true
                )
        }
    }
}

#Preview("Wind - Two") {
    ScrollView(showsIndicators: false) {
        Image("Map")
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    WindTumbleweedView(mapSize: geo.size)
                }
            }
    }
    .background(Color.light2)
}
