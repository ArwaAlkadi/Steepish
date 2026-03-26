import SwiftUI
import UIKit
import Lottie

import SwiftUI
import UIKit
import Lottie

struct SplashView: View {

 

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                LottieAnimationViewRepresentable(fileName: "walkingshoes")
                    .frame(width: 320, height: 320)
                   
            }
        }
       
    }
}

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

