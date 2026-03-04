//
//  JoinCodePopup.swift
//  StepGame
//

import SwiftUI
import Combine

struct JoinCodePopup: View {

    @Binding var isPresented: Bool

    @State private var code: String = ""
    @State private var errorText: String? = nil
    @FocusState private var focused: Bool

    @State private var isSubmitting: Bool = false

    // MARK: - Join Action Callback
    /// Return:
    /// - nil  => success (close popup)
    /// - msg  => failure (show msg)
    let onJoin: (String) async -> String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 18) {

                HStack {
                    Spacer()
                    Button { close() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.light1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.6 : 1)
                }

                Text("Join with code")
                    .font(.custom("RussoOne-Regular", size: 22))
                    .foregroundStyle(.light1)

                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(height: 46)

                        TextField(
                            "",
                            text: $code,
                            prompt: Text("ex: QU123Z...")
                                .foregroundColor(Color.light1.opacity(0.3))
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(Color.light1)
                        .padding(.horizontal, 16)
                            .focused($focused)
                            .disabled(isSubmitting)
                            .onChange(of: code) { _, newValue in
                                let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                                code = String(filtered.prefix(6))
                                errorText = nil
                            }
                    }

                    if let errorText {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red1)
                                .font(.system(size: 12))
                            Text(errorText)
                                .font(.custom("RussoOne-Regular", size: 12))
                                .foregroundStyle(.red1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                    }
                }
               

                Button {
                    Task {
                        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

                        guard trimmed.count >= 4 else {
                            errorText = "Invalid code. Try again."
                            return
                        }

                        isSubmitting = true
                        errorText = nil

                        let err = await onJoin(trimmed)

                        isSubmitting = false

                        if let err {
                            errorText = err
                            focused = true
                        } else {
                            close()
                        }
                    }
                } label: {
                    Text(isSubmitting ? "Joining..." : "Join")
                        .font(.custom("RussoOne-Regular", size: 18))
                        .foregroundStyle(.light3)
                        .frame(width: 130, height: 44)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.light1))
                }
                .disabled(code.isEmpty || isSubmitting)
                .opacity((code.isEmpty || isSubmitting) ? 0.5 : 1)
                .padding(.bottom)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 26).fill(Color.light3))
            .onAppear { focused = true }
        }
    }

    private func close() {
        withAnimation(.easeInOut) { isPresented = false }
    }
}
