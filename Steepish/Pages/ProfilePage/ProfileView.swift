//
//  ProfileView.swift
//  Steepish
//

import SwiftUI
import Combine

// MARK: - Profile View

/// Displays the player's avatar and name, with an inline editing mode for changing
/// the character and display name.
struct ProfileView: View {

    @EnvironmentObject private var session: UserSession
    @EnvironmentObject private var connectivity: ConnectivityMonitor

    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showOfflineBanner: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.light3.ignoresSafeArea()

            VStack(spacing: 28) {
                topBar

                Spacer(minLength: 10)

                if vm.isEditing {
                    editingContent
                } else {
                    viewContent
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)

            OfflineBanner(isVisible: $showOfflineBanner)
        }
        .onAppear {
            vm.loadFromSession(session.player)
        }
        .onChange(of: session.player?.id) { _, _ in
            vm.loadFromSession(session.player)
        }
        .onChange(of: connectivity.isOnline) { _, online in
            if online {
                withAnimation(.easeInOut) { showOfflineBanner = false }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if vm.isEditing {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(Color.light1)
                }

            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.light1)
                }
            }

            Spacer()

            if vm.isEditing {
                Button {
                    Task { await doneTapped() }
                } label: {
                    Text("Done")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(Color.light1)
                }
                .disabled(vm.isSaving || !vm.hasChanges)
                .opacity((vm.isSaving || !vm.hasChanges) ? 0.6 : 1)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - View Mode Content

    private var viewContent: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AvatarCircle(
                    imageName: vm.selectedCharacter.normalKey(),
                    size: 290
                )

                Button {
                    vm.enterEdit()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(Color.light1)
                }
                .offset(x: -25, y: -20)
            }

            Text(vm.displayName)
                .font(.custom("RussoOne-Regular", size: 34))
                .foregroundStyle(Color.light1)
        }
    }

    // MARK: - Editing Content

    private var editingContent: some View {
        VStack(spacing: 20) {
            CharacterCarousel(
                selection: $vm.selectedCharacter,
                all: vm.allCharacters
            )

            CapsuleIndicator(currentIndex: vm.selectedIndex, total: vm.allCharacters.count)

            nameEditor

            if vm.isSaving {
                Text("Saving...")
                    .font(.custom("RussoOne-Regular", size: 14))
                    .foregroundStyle(Color.light2)
            }
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("Name")
                .font(.custom("RussoOne-Regular", size: 14))
                .foregroundStyle(Color.light1)
                .padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.light4.opacity(0.7))
                    .stroke(Color.light1, lineWidth: 2)
                    .frame(height: 54)

                TextField(
                    "",
                    text: $vm.draftName,
                    prompt: Text("Name")
                        .foregroundColor(Color.light1.opacity(0.4))
                )
                .font(.custom("RussoOne-Regular", size: 22))
                .foregroundStyle(Color.light1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .onChange(of: vm.draftName) { _, newValue in
                    if newValue.count > 15 {
                        vm.draftName = String(newValue.prefix(15))
                    }
                    if vm.nameError != nil {
                        vm.nameError = nil
                    }
                }
            }

            HStack {
                if let err = vm.nameError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red1)
                        Text(err)
                            .font(.custom("RussoOne-Regular", size: 12))
                            .foregroundStyle(.red1)
                    }
                }
                Spacer()
                Text("\(vm.draftName.count)/15")
                    .font(.custom("RussoOne-Regular", size: 12))
                    .foregroundStyle(vm.draftName.count > 15 ? .red1 : Color.light2)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: 320)
    }

    // MARK: - Actions

    /// Validates and saves the profile edits, showing the offline banner if there's no connection.
    private func doneTapped() async {

        guard connectivity.isOnline else {
            withAnimation(.easeInOut) { showOfflineBanner = true }
            return
        }

        guard let sessionPlayer = session.player else { return }

        let ok = vm.validateDraft()
        guard ok else { return }

        await vm.save(session: session, currentPlayer: sessionPlayer)
    }
}

// MARK: - Avatar Circle

/// Circular avatar image on a soft background circle.
private struct AvatarCircle: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.light4.opacity(0.6))
                .frame(width: size, height: size)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.82, height: size * 0.82)
        }
    }
}

// MARK: - Character Carousel

/// Swipeable carousel for choosing between the available character types.
private struct CharacterCarousel: View {

    @Binding var selection: CharacterType
    let all: [CharacterType]

    var body: some View {
        TabView(selection: $selection) {
            ForEach(all, id: \.rawValue) { type in
                AvatarCircle(imageName: type.normalKey(), size: 290)
                    .tag(type)
                    .padding(.horizontal, 30)
            }
        }
        .frame(height: 300)
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: - Capsule Indicator

/// Row of capsule dots indicating the selected index within a fixed total.
private struct CapsuleIndicator: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == currentIndex ? Color.light1 : Color.light1.opacity(0.25))
                    .frame(width: i == currentIndex ? 26 : 8, height: 6)
            }
        }
    }
}

