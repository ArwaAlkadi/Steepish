//
//  MapPathEditorHelper.swift
//  StepGame
//

import Foundation
import SwiftUI

// MARK: - Map Path Editor Helper
struct MapPathEditorHelper: View {
    
    private let pathPoints: [CGPoint] = [
        .init(x: 0.714, y: 0.890), // 0
        .init(x: 0.726, y: 0.851), // 1
        .init(x: 0.735, y: 0.812), // 2
        .init(x: 0.670, y: 0.773), // 3
        .init(x: 0.500, y: 0.734), // 4
        .init(x: 0.530, y: 0.695), // 5
        .init(x: 0.600, y: 0.656), // 6
        .init(x: 0.560, y: 0.617), // 7
        .init(x: 0.520, y: 0.578), // 8
        .init(x: 0.410, y: 0.539), // 9
        .init(x: 0.390, y: 0.500), // 10
        .init(x: 0.450, y: 0.461), // 11
        .init(x: 0.620, y: 0.422), // 12
        .init(x: 0.700, y: 0.383), // 13
        .init(x: 0.550, y: 0.344), // 14
        .init(x: 0.500, y: 0.305), // 15
        .init(x: 0.520, y: 0.266), // 16
        .init(x: 0.650, y: 0.227), // 17
        .init(x: 0.790, y: 0.188), // 18
        .init(x: 0.790, y: 0.150), // 19
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            Image("Map")
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { geo in
                        ZStack {
                            // Draw Path
                            Path { path in
                                guard let first = pathPoints.first else { return }
                                
                                let startPoint = CGPoint(
                                    x: first.x * geo.size.width,
                                    y: first.y * geo.size.height
                                )
                                path.move(to: startPoint)
                                
                                for point in pathPoints.dropFirst() {
                                    let scaledPoint = CGPoint(
                                        x: point.x * geo.size.width,
                                        y: point.y * geo.size.height
                                    )
                                    path.addLine(to: scaledPoint)
                                }
                            }
                            .stroke(Color.blue, lineWidth: 3)
                            
                            // Draw Points
                            ForEach(Array(pathPoints.enumerated()), id: \.offset) { index, point in
                                Circle()
                                    .fill(index == 0 ? Color.green : (index == pathPoints.count - 1 ? Color.red : Color.blue))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text("\(index)")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .position(
                                        x: point.x * geo.size.width,
                                        y: point.y * geo.size.height
                                    )
                            }
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
