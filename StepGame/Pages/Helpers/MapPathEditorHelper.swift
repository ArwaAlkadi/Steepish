//
//  MapPathEditorHelper.swift
//  StepGame
//

import Foundation
import SwiftUI

// MARK: - Map Path Editor Helper
struct MapPathEditorHelper: View {

    @State private var points: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                Color.black.ignoresSafeArea()

                Image("Map")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        GeometryReader { innerGeo in
                            let mapSize = innerGeo.size

                            ForEach(points.indices, id: \.self) { i in
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 14, height: 14)
                                    .position(
                                        x: points[i].x * mapSize.width,
                                        y: points[i].y * mapSize.height
                                    )
                            }

                            /// Tap to append a normalized point
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            let x = min(max(value.location.x / mapSize.width, 0), 1)
                                            let y = min(max(value.location.y / mapSize.height, 0), 1)

                                            let newPoint = CGPoint(x: x, y: y)
                                            points.append(newPoint)

                                            print("    .init(x: \(String(format: "%.3f", x)), y: \(String(format: "%.3f", y))),")
                                        }
                                )
                        }
                    }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    MapPathEditorHelper()
}


