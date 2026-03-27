import SwiftUI
import Combine
import UIKit

struct RootView: View {

    @EnvironmentObject private var session: GameSession
    @EnvironmentObject private var health: HealthKitManager

    @Environment(\.scenePhase) private var scenePhase

    @State private var didFinishBootstrap = false
    @State private var showUpdateAlert = false
    @State private var updateMessage = ""

    // MARK: - Onboarding (Shown Once)
    @AppStorage("didShowOnboarding") private var didShowOnboarding: Bool = false
    @State private var showOnboardingNow: Bool = false

    // MARK: - Router Identity Key
    /// Forces NavigationStack to rebuild when critical session/health state changes
    private var routerKey: String {
        let id = session.challenge?.id ?? "no_ch"
        let status = session.challenge?.status.rawValue ?? "none"
        let player = session.player?.id ?? "no_player"
        let healthState = health.isAuthorized ? "hk_ok" : "hk_off"
        let onboard = didShowOnboarding ? "ob_done" : "ob_no"
        return "\(player)_\(id)_\(status)_\(healthState)_\(onboard)"
    }

    var body: some View {
        ZStack {
            if didFinishBootstrap {
                NavigationStack {
                    Group {

                        // MARK: - Onboarding Flow
                        if showOnboardingNow && !didShowOnboarding {
                            OnboardingView(onFinish: {
                                didShowOnboarding = true
                                showOnboardingNow = false
                            })
                        }

                        // MARK: - Require Player Name
                        else if session.player == nil {
                            EnterNameView()
                        }

                        // MARK: - HealthKit Not Authorized
                        else if !health.isAuthorized {
                            StartView()
                        }

                        // MARK: - No Active or Available Challenges
                        else if session.challenge == nil && session.challenges.isEmpty {
                            StartView()
                        }

                        // MARK: - Challenge Routing
                        else {
                            challengeRouter
                        }
                    }
                }
                .id(routerKey)
                .transition(.opacity)

            } else {

                // MARK: - Splash (Initial Bootstrap Loading)
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: didFinishBootstrap)
        .task {

            // MARK: - App Bootstrap
            if !didFinishBootstrap {
                async let bootstrap: () = session.bootstrap()
                async let healthRefresh: () = health.refreshAuthorizationState()
                async let minDelay: () = Task.sleep(nanoseconds: 1_800_000_000)

                _ = try? await (bootstrap, healthRefresh, minDelay)

                didFinishBootstrap = true

                if !didShowOnboarding {
                    showOnboardingNow = true
                }
            }

            await checkVersion()
        }

        // MARK: - Refresh Health Authorization On App Active
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await health.refreshAuthorizationState() }
        }

        // MARK: - Update Alert Overlay
        .overlay {
            if showUpdateAlert {
                UpdateAlertView(
                    message: updateMessage,
                    onUpdate: {
                        openAppStore()
                    }
                )
                .transition(.opacity)
                .zIndex(9999)
            }
        }
    }

    // MARK: - Challenge Router
    @ViewBuilder
    private var challengeRouter: some View {
        if let ch = session.challenge {
            if ch.originalMode == .social && ch.status == .waiting {
                WaitingRoomView()
            } else {
                MapView()
            }
        } else {
            SplashView()
        }
    }
    
    // MARK: - Update Alert View

    struct UpdateAlertView: View {
        let message: String
        let onUpdate: () -> Void
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 15) {
                    
                    Text("Update Required")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(.light1)
                    
                    Text(message)
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(.light2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        onUpdate()
                    } label: {
                        Text("Update Now")
                            .font(.custom("RussoOne-Regular", size: 16))
                            .foregroundStyle(.light3)
                            .frame(width: 160, height: 40)
                            .background(RoundedRectangle(cornerRadius: 22).fill(Color.light1))
                    }
                }
                .padding(.vertical)
                .padding(20)
                .frame(maxWidth: 320)
                .background(RoundedRectangle(cornerRadius: 26).fill(Color.light3))
            }
        }
    }

    // MARK: - Version Check

    private func checkVersion() async {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        do {
            let config = try await AppConfig.fetch()
            
            print("Current version: \(currentVersion)")
            print("Minimum version from Firebase: \(config.minimumVersion)")
            
            if currentVersion.isOlderThan(config.minimumVersion) {
                print("Update required")
                await MainActor.run {
                    updateMessage = config.message
                    showUpdateAlert = true
                }
            } else {
                print("App version is OK")
            }
        } catch {
            print("Failed to check version: \(error)")
        }
    }

    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/app/id6759177856") {
            UIApplication.shared.open(url)
        }
    }
}
