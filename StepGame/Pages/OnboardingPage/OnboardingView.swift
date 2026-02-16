import SwiftUI
import Combine

struct OnboardingView: View {

    @StateObject private var viewModel = OnboardingViewModel()

    var onFinish: () -> Void = {}

    var body: some View {

        VStack {

            // MARK: - Top Bar
            HStack {
                Spacer()
                if viewModel.currentPage < viewModel.totalPages - 1 {
                    Button("Skip") {
                        onFinish()
                    }
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundColor(Color.light2)
                    .padding(.trailing, 24)
                    .padding(.top, 12)
                }
            }

            TabView(selection: $viewModel.currentPage) {

                // Page 0
                pageView(pageIndex: 0)
                    .tag(0)

                // Page 1
                pageView(pageIndex: 1)
                    .tag(1)

                // Page 2
                pageView(pageIndex: 2)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentPage)

            // MARK: - Bottom Controls
            HStack {

                // Progress Dots
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.totalPages, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == viewModel.currentPage
                                ? Color.light2
                                : Color.light2.opacity(0.3)
                            )
                            .frame(
                                width: index == viewModel.currentPage ? 28 : 8,
                                height: 8
                            )
                    }
                }

                Spacer()

                // Button
                Button {
                    if viewModel.currentPage == viewModel.totalPages - 1 {
                        onFinish()
                    } else {
                        viewModel.next()
                    }
                } label: {
                    Text(viewModel.currentPage == viewModel.totalPages - 1 ? "Get Started" : "Next")
                        .font(.custom("RussoOne-Regular", size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.light2)
                        .cornerRadius(28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(
            Color(red: 0.98, green: 0.94, blue: 0.88)
                .ignoresSafeArea()
        )
    }

    private func pageView(pageIndex: Int) -> some View {

        VStack {

            Spacer()

            // MARK: - Title
            Text(titleText(for: pageIndex))
                .font(.custom("RussoOne-Regular", size: 28))
                .foregroundColor(Color.light1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            
                characterView(imageName: characterImage(for: pageIndex))
          

            // MARK: - Subtitle
            Text(subtitleText(for: pageIndex))
                .font(.custom("RussoOne-Regular", size: 20))
                .foregroundColor(.light1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .padding(.top, 24)

            Spacer()
        }
    }
}

// MARK: - Reusable Views
extension OnboardingView {

    func characterView(imageName: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.light2.opacity(0.1))
                .frame(width: 260, height: 260)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 330, height: 350)
                .offset(y: -10)
        }
    }

    
}

// MARK: - Page Content
extension OnboardingView {

    func titleText(for page: Int) -> String {
        switch page {
        case 0: return "Walk • Play • Win"
        case 1: return "Your Character Shows\nYour Progress"
        case 2: return "Walk, think, and compete"
        default: return ""
        }
    }

    func subtitleText(for page: Int) -> String {
        switch page {
        case 0: return "Turn your daily steps into an exciting game"
        case 1: return "The more you move, the better your character looks"
        case 2: return "Play solo or challenge a friend. Track your challenge with the Steepish Widget!"
        default: return ""
        }
    }

    func characterImage(for page: Int) -> String {
        switch page {
        case 0: return "lunawalk"
        case 1: return "lunawin"
        default: return "wid"
        }
    }
}

#Preview {
    OnboardingView()
}
