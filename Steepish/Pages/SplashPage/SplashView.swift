//
//  SplashView.swift
//  Steepish
//

import SwiftUI
import UIKit
import Lottie

// MARK: - Splash View

/// Animated launch screen shown while the app bootstraps: a Lottie walking-shoes animation
/// followed by a fading tagline.
struct SplashView: View {

    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 20

    var body: some View {
        ZStack {
            Color(.light3)
                .ignoresSafeArea()

            LottieAnimationViewRepresentable(fileName: "walkingshoes")
                .frame(width: 300, height: 300)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
//                        .background(Color(.light1).opacity(0.1))
                .offset(x: 0, y: -20)

            VStack(spacing: 5) {
                Spacer()

                Rectangle()
                    .frame(height: 150)
                    .foregroundStyle(.clear)

                Text("Walk. Compete. Win.")
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundColor(.light1)
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                logoScale = 1.0
                logoOpacity = 1
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                titleOpacity = 1
                titleOffset = 0
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                taglineOpacity = 1
                taglineOffset = 0
            }
        }
    }
}

// MARK: - Lottie Animation Representable

/// Wraps a looping `LottieAnimationView` for use in SwiftUI.
struct LottieAnimationViewRepresentable: UIViewRepresentable {
    let fileName: String

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)

        let animationView = LottieAnimationView(name: fileName)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play()

        animationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor),
            animationView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) { }
}

#Preview {
    SplashView()
}

