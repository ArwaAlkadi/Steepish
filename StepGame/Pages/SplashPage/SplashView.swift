import SwiftUI

struct SplashView: View {

    @State private var show = false

    var body: some View {
        ZStack {

            // Background
            Color(red: 0.97, green: 0.94, blue: 0.90)
                .ignoresSafeArea()

            // ===== stepbig (2 خطوات - أسفل يسار) =====
            ForEach(0..<2, id: \.self) { i in
                Image("stepbig")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72)
                    .opacity(show ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.28)
                            .delay(Double(i) * 0.10),
                        value: show
                    )
                    .position(
                        x: 85 + CGFloat(i * 25),
                        y: 750 - CGFloat(i * 55)
                    )
            }

            // ===== stepsleft (4 خطوات - يسار) =====
            ForEach(0..<4, id: \.self) { i in
                Image("stepsleft")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .opacity(show ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.28)
                            .delay(0.18 + Double(i) * 0.10),
                        value: show
                    )
                    .position(
                        x: 170 - CGFloat(i * 30),
                        y: 650 - CGFloat(i * 45)
                    )
            }

            // ===== stepsright (3 خطوات - تحت) =====
            ForEach(0..<3, id: \.self) { i in
                Image("stepsleft")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30)
                    .opacity(show ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.24)
                            .delay(0.40 + Double(i) * 0.10),
                        value: show
                    )
                    .position(
                        x: 100 + CGFloat(i * 20),
                        y: 480 - CGFloat(i * 32)
                    )
            }

            // ===== stepsleft الصغيرة (2 - فوق) =====
            ForEach(0..<2, id: \.self) { i in
                Image("stepsleft")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23)
                    .opacity(show ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.24)
                            .delay(0.58 + Double(i) * 0.10),
                        value: show
                    )
                    .position(
                        x: 100 - CGFloat(i * 20),
                        y: 390 - CGFloat(i * 32)
                    )
            }

            // ===== Title =====
            Text("STEEPISH")
                .font(.custom("Russo One", size: 44))
                .foregroundColor(Color(red: 0.29, green: 0.12, blue: 0.06))
                .opacity(show ? 1 : 0)
                .animation(
                    .easeIn(duration: 0.30)
                        .delay(0.75),
                    value: show
                )
                .position(
                    x: UIScreen.main.bounds.width / 2,
                    y: UIScreen.main.bounds.height * 0.32
                )
        }
        .onAppear {
            show = true
        }
    }
}

#Preview {
    SplashView()
}

