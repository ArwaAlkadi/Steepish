//
//   SetupChallengeView.swift
//  StepGame
//

import SwiftUI
import Combine

import SwiftUI
import Combine

struct SetupChallengeView: View {

    @Binding var isPresented: Bool
    var onDismissWithoutCreating: (() -> Void)? = nil

    @EnvironmentObject private var connectivity: ConnectivityMonitor
    @EnvironmentObject var session: GameSession
    @StateObject private var vm = SetupChallengeViewModel()

    @State private var showOfflineBanner: Bool = true

    var body: some View {
        ZStack {
            Color.light3.ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Content
                VStack(spacing: 18) {

                    HStack {
                        Spacer()
                        Button {
                            isPresented = false
                            onDismissWithoutCreating?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(.light1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 40)
                       
                    }
            

                    HStack(spacing: 0) {
                        Text("Create a New Challenge")
                            .font(.custom("RussoOne-Regular", size: 24))
                            .foregroundStyle(.light2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image("Flag3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35, height: 35)
                           

                    }
                
                    // Challenge Name
                    VStack(alignment: .leading, spacing: 6) {

                        Text("Name of the challenge")
                            .font(.custom("RussoOne-Regular", size: 18))
                            .foregroundStyle(Color.light1)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.light4.opacity(0.55))
                                .frame(height: 46)

                            TextField(
                                "",
                                text: $vm.challengeName,
                                prompt: Text("Ex: Go ahead 💪🏻")
                                    .foregroundColor(Color.light1.opacity(0.4))
                            )
                            .font(.custom("RussoOne-Regular", size: 16))
                            .foregroundStyle(Color.light1)
                            .padding(.horizontal, 14)
                            .onChange(of: vm.challengeName) { _, _ in
                                vm.clampName()
                            }
                        }

                        HStack {
                            Text("\(vm.challengeName.count)/\(vm.maxNameCount)")
                            Spacer()
                            if let err = vm.errorMessage {
                                Text(err).foregroundStyle(.red)
                            }
                        }
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.light2)
                        .padding(.leading, 6)
                    }

                    // Period Selection
                    VStack(alignment: .leading, spacing: 10) {

                        Text("Period")
                            .font(.custom("RussoOne-Regular", size: 18))
                            .foregroundStyle(Color.light1)

                        HStack(spacing: 12) {
                            ForEach(PeriodOption.allCases, id: \.title) { option in
                                PeriodChip(
                                    title: option.title,
                                    isSelected: vm.selectedPeriod == option
                                ) {
                                    vm.selectedPeriod = option
                                }
                            }
                        }
                    }

                    // Step Goal
                    VStack(alignment: .leading, spacing: 10) {

                        Text("Steps")
                            .font(.custom("RussoOne-Regular", size: 18))
                            .foregroundStyle(Color.light1)

                        CustomStepSlider(
                            value: $vm.steps,
                            min: 1000,
                            max: 1_000_000,
                            step: 100,
                            fillColor: Color.light2,
                            trackColor: Color.white
                        )
                        .onChange(of: vm.steps) { _, newValue in
                            vm.steps = (newValue / 100).rounded() * 100
                        }
                        .frame(height: 34)

                        HStack {
                            Text("1000")

                            Spacer()

                            Text("\(Int(vm.steps).formatted())")
                                .font(.custom("RussoOne-Regular", size: 14))
                                .foregroundStyle(Color.light1.opacity(0.9))

                            Spacer()

                            Text("1,000,000")
                        }
                        .font(.custom("RussoOne-Regular", size: 12))
                        .foregroundStyle(Color.light2)
                    }

                    // Mode Selection
                    HStack(spacing: 14) {

                        ModeChip(
                            title: "Solo",
                            systemIcon: "person.fill",
                            isSelected: vm.mode == .solo
                        ) {
                            vm.mode = .solo
                        }

                        ModeChip(
                            title: "Group",
                            systemIcon: "person.2.fill",
                            isSelected: vm.mode == .group
                        ) {
                            vm.mode = .group
                        }
                    }

                    Spacer(minLength: 6)

                    // Create Challenge
                    Button {
                        guard connectivity.isOnline else { return }

                        Task {
                            let outcome = await vm.createChallenge(session: session)

                            switch outcome {
                            case .soloCreated, .groupCreated:
                                isPresented = false
                            case .failed:
                                break
                            }
                        }
                    } label: {
                        Text(session.isLoading ? "Creating..." : "Create")
                            .font(.custom("RussoOne-Regular", size: 18))
                            .foregroundStyle(Color.light3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(Color.light1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isLoading || !connectivity.isOnline)
                    .opacity((session.isLoading || !connectivity.isOnline) ? 0.6 : 1.0)
                    .padding(.top, 8)
                }
                .offset(y: -40)
                .padding(18)
                .frame(maxWidth: 380)
                .padding(.horizontal, 20)
            }

            if !connectivity.isOnline {
                OfflineBanner(isVisible: $showOfflineBanner)
            }
        }
    }
}

// MARK: - Components

private struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("RussoOne-Regular", size: 14))
                .foregroundStyle(isSelected ? Color.white : Color.light1)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.light2 : Color.white)
                        .overlay(
                            Capsule()
                                .stroke(Color.light4.opacity(0.35), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ModeChip: View {
    let title: String
    let systemIcon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemIcon)
                Text(title)
            }
            .font(.custom("RussoOne-Regular", size: 14))
            .foregroundStyle(isSelected ? Color.white : Color.light1)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Capsule()
                    .fill(isSelected ? Color.light2 : Color.white)
                    .overlay(
                        Capsule().stroke(Color.light4.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Host
#Preview("SetupChallengeView") {
    SetupChallengePreviewHost()
}

// MARK: - Preview Host
private struct SetupChallengePreviewHost: View {
    @State private var presented: Bool = true

    @StateObject private var session = GameSession()
    @StateObject private var health = HealthKitManager()
    @StateObject private var connectivity = ConnectivityMonitor()

    var body: some View {
        SetupChallengeView(isPresented: $presented)
            .environmentObject(session)
            .environmentObject(health)
            .environmentObject(connectivity)
            .onAppear {
                if session.player == nil {
                    session.player = Player(
                        id: "preview_uid",
                        name: "Arwa",
                        totalChallenges: 0,
                        completedChallenges: 0,
                        totalSteps: 0,
                        characterType: .character1,
                        lastUpdated: Date(),
                        createdAt: Date()
                    )
                    session.playerName = "Arwa"
                }
            }
    }
}


// MARK: - Custom flat slider 
private struct CustomStepSlider: View {

    @Binding var value: Double
    let min: Double
    let max: Double
    let step: Double
    let fillColor: Color
    let trackColor: Color

    private let trackHeight: CGFloat = 12
    private let thumbSize: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let available = Swift.max(1, width - thumbSize)

            let safeValue = Swift.min(Swift.max(value, min), max)
            let progress = CGFloat((safeValue - min) / (max - min))
            let x = progress * available

            ZStack(alignment: .leading) {

                Capsule()
                    .fill(trackColor)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: x + thumbSize / 2, height: trackHeight)

                Circle()
                    .fill(fillColor)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let loc = Swift.min(
                            Swift.max(0, g.location.x - thumbSize / 2),
                            available
                        )
                        let raw = Double(loc / available) * (max - min) + min
                        let snapped = (raw / step).rounded() * step
                        value = Swift.min(Swift.max(snapped, min), max)
                    }
            )
        }
        .frame(height: thumbSize)
        .accessibilityValue(Text("\(Int(value))"))
    }
}
