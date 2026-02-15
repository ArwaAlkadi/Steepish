//
//  MapView.swift
//  StepGame
//

import SwiftUI
import UIKit
import Combine

struct MapView: View {

    @EnvironmentObject  var session: GameSession
      @EnvironmentObject  var health: HealthKitManager
      @EnvironmentObject  var connectivity: ConnectivityMonitor

      @StateObject var vm = MapViewModel()

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
        }
        .onReceive(uiTimer) { t in
            now = t
            vm.evaluateSoloLate(now: t)  
        }
        .onDisappear {
            if isPresentingCover { return }
            vm.stopStepsSync()
            vm.unbind()
        }
        .onChange(of: session.challenge?.id) { _, _ in
            vm.bind(session: session)
            vm.startStepsSync(health: health)
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
}
