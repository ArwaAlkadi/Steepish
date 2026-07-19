//
//  EnterNameView.swift
//  Steepish
//

import SwiftUI
import UIKit
import Combine

// MARK: - Enter Name View

/// First-run screen where the player enters their display name before starting.
struct EnterNameView: View {

    @EnvironmentObject var session: UserSession
    @EnvironmentObject private var connectivity: ConnectivityMonitor

    @StateObject private var vm = EnterNameViewModel()
    @StateObject private var keyboard = KeyboardObserver()

    @State private var showOfflineBanner: Bool = false

    var body: some View {
        ZStack(alignment: .top) {

            Image("Map")
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .blur(radius: 4)
                .ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    Image("Enter nameP")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .offset(y: -260)

                    ZStack {
                        Rectangle()
                            .foregroundStyle(.light2)
                            .frame(height: 330)
                            .cornerRadius(40)
                            .ignoresSafeArea(edges: .bottom)

                        VStack(spacing: 30) {

                            // MARK: - Title
                            Text("Enter Your Name!")
                                .font(.custom("RussoOne-Regular", size: 30))
                                .foregroundStyle(.light3)

                            VStack(alignment: .trailing, spacing: 8) {

                                // MARK: - Name Input
                                ZStack {
                                    RoundedRectangle(cornerRadius: 28)
                                        .foregroundStyle(.light3.opacity(0.25))
                                        .frame(height: 56)

                                    TextField(
                                        "",
                                        text: $vm.name,
                                        prompt: Text("Name")
                                            .foregroundColor(Color.light3.opacity(0.4))
                                    )
                                    .font(.custom("RussoOne-Regular", size: 20))
                                    .foregroundStyle(Color.light3)
                                    .padding(.horizontal, 20)
                                    .onChange(of: vm.name) { _, newValue in
                                        vm.enforceNameLimit(newValue)
                                    }
                                }

                                // Character Count
                                Text("\(vm.name.count)/\(vm.maxNameCount)")
                                    .font(.custom("RussoOne-Regular", size: 14))
                                    .foregroundStyle(.light3)
                                    .padding(.horizontal, 8)
                            }
                            .padding(.horizontal, 24)

                            // MARK: - Start Action
                            Button {
                                guard connectivity.isOnline else {
                                    withAnimation(.easeInOut) { showOfflineBanner = true }
                                    return
                                }

                                Task { await session.createPlayer(name: vm.name) }
                            } label: {
                                Text(session.isLoading ? "Saving..." : "Start")
                                    .font(.custom("RussoOne-Regular", size: 26))
                                    .foregroundStyle(.light3)
                                    .frame(width: 200, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 36)
                                            .foregroundStyle(.light1)
                                    )
                            }
                            .disabled(!vm.isStartEnabled || session.isLoading || !connectivity.isOnline)
                            .opacity((!vm.isStartEnabled || session.isLoading || !connectivity.isOnline) ? 0.5 : 1)

                            // Error Message
                            if let msg = session.errorMessage {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.red1)
                                    Text(msg)
                                        .font(.custom("RussoOne-Regular", size: 12))
                                        .foregroundStyle(Color.red1)
                                }
                                .padding(.top, 6)
                            }
                        }
                        .padding(.top, 26)
                    }
                }
                .padding(.bottom, keyboard.height * 0.25)
                .animation(.easeOut(duration: 0.25), value: keyboard.height)
            }

            if !connectivity.isOnline {
                OfflineBanner(isVisible: $showOfflineBanner)
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}

#Preview("EnterNameView") {
    EnterNamePreviewHost()
}

// MARK: - Preview Host

private struct EnterNamePreviewHost: View {
    @StateObject private var session = UserSession()
    @StateObject private var connectivity = ConnectivityMonitor()

    var body: some View {
        NavigationStack {
            EnterNameView()
                .environmentObject(session)
                .environmentObject(connectivity)
        }
        .onAppear {
            session.player = nil
            session.playerName = ""
        }
    }
}

// MARK: - Keyboard Observer

/// Publishes the current keyboard height so views can adjust their layout while it's visible.
final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: \.height, on: self)
            .store(in: &cancellables)
    }
}

