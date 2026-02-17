//
//  MapView.swift
//  StepGame
//

import SwiftUI
import UIKit
import Combine

struct MapView: View {

    @EnvironmentObject var session: GameSession
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var connectivity: ConnectivityMonitor

    @StateObject var vm = MapViewModel()
    
    @State private var hasScrolledToPlayer = false

    @State var selectedDetent: PresentationDetent = .height(90)
    @State var showJoinPopup = false
    @State var showSetupPage = false
    @State var showProfile = false
    @State var showOfflineBanner = true
    @State var puzzleResult: PuzzleResult? = nil
    @State var activeMapPopup: MapPopupType? = nil
    @State var activePuzzle: PuzzleRequest? = nil

    enum ActiveSheet: Identifiable {
        case challenges
        var id: Int { 1 }
    }

    @State var activeSheet: ActiveSheet? = .challenges
    @State var now = Date()
    let uiTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var isPresentingCover: Bool {
        showJoinPopup || showSetupPage || showProfile || (activePuzzle != nil)
    }

    var body: some View {
        ZStack {
            Color.light2.ignoresSafeArea()

            mapContent
            hudLayer
            resultPopup
            mapPopupLayer
            puzzleResultOverlay

            if !connectivity.isOnline {
                OfflineBanner(isVisible: $showOfflineBanner)
            }
        }
        .sheet(item: $activeSheet) { _ in
            makeChallengesSheet()
        }
        .fullScreenCover(isPresented: $showJoinPopup, onDismiss: showChallengesSheet) {
            makeJoinPopup()
        }
        .fullScreenCover(isPresented: $showSetupPage, onDismiss: showChallengesSheet) {
            makeSetupView()
        }
        .fullScreenCover(isPresented: $showProfile, onDismiss: showChallengesSheet) {
            makeProfileView()
        }
        .fullScreenCover(item: $activePuzzle, onDismiss: showChallengesSheet) { req in
            PuzzleWiringView(
                timeLimit: 8,
                onCancel: {
                    activePuzzle = nil
                },
                onFinish: { success, time, didTimeout in
                    Task { await handlePuzzleFinish(req: req, success: success, time: time, didTimeout: didTimeout) }
                }
            )
        }
        .onAppear {
            selectedDetent = .height(90)
            showChallengesSheet()
            vm.bind(session: session)
            vm.startStepsSync(health: health)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                scrollToPlayerPosition()
            }
        }
        .onReceive(uiTimer) { t in
            now = t
            vm.evaluateSoloLate(now: t)
        }
        .onDisappear {
            if isPresentingCover { return }
            vm.stopStepsSync()
            vm.unbind()
            hasScrolledToPlayer = false
        }
        .onChange(of: session.challenge?.id) { _, _ in
            vm.bind(session: session)
            vm.startStepsSync(health: health)
            hasScrolledToPlayer = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                scrollToPlayerPosition()
            }
        }
        .onChange(of: session.player?.name) { _, _ in
            vm.bind(session: session)
        }
        .onChange(of: session.player?.characterType) { _, _ in
            vm.bind(session: session)
        }
        .onChange(of: vm.pendingMapPopup) { popup in
            activeMapPopup = popup
        }
    }
    
    
    private func scrollToPlayerPosition() {
        guard !hasScrolledToPlayer else {
            print("Already scrolled to player")
            return
        }
        
        guard let me = vm.mapPlayers.first(where: { $0.isMe }) else {
            print("Player not found in mapPlayers")
            return
        }
        
        let mapWidth = UIScreen.main.bounds.width
        let mapHeight: CGFloat = 2000
        
        let playerPos = vm.positionForPlayer(me, mapSize: CGSize(width: mapWidth, height: mapHeight))
        
        print("Player position: \(playerPos)")
        print("Player progress: \(me.progress)")
        
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }) else {
                print("❌ No key window found")
                return
            }
            
            guard let scrollView = findScrollView(in: window) else {
                print("ScrollView not found")
                return
            }
            
            print("ScrollView found")
            print("   contentSize: \(scrollView.contentSize)")
            print("   bounds: \(scrollView.bounds)")
            
            let targetX = max(0, min(
                playerPos.x - mapWidth / 2,
                scrollView.contentSize.width - scrollView.bounds.width
            ))
            
            let targetY = max(0, min(
                playerPos.y - 300,
                scrollView.contentSize.height - scrollView.bounds.height
            ))
            
            let targetOffset = CGPoint(x: targetX, y: targetY)
            
            print("Scrolling to: \(targetOffset)")
            
            UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseInOut) {
                scrollView.setContentOffset(targetOffset, animated: false)
            } completion: { _ in
                print("Scroll completed")
            }
            
            hasScrolledToPlayer = true
        }
    }
    
    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            if scrollView.frame.width > 100 && scrollView.frame.height > 100 {
                return scrollView
            }
        }
        
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        
        return nil
    }
}
