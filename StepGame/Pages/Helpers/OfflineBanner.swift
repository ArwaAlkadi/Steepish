//
//  OfflineBanner.swift
//  StepGame
//

import SwiftUI

struct OfflineBanner: View {

    @Binding var isVisible: Bool  

    var body: some View {

        if isVisible {
            
            VStack {
            HStack(spacing: 10) {
                Image("WI-FI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                   
                
                Text("Uh-oh! You’re Offline..")
                    .font(.custom("RussoOne-Regular", size: 16))
                    .foregroundStyle(.light3)

                Spacer()

                Button {
                    withAnimation(.easeInOut) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.light3)
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.light3)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.light1)
            )
            .padding(.horizontal, 14)
            .padding(.top, 20)
                
                Spacer()
          }
        }
    }
}

#Preview {
    StatefulPreviewWrapper(true) { isVisible in
        OfflineBanner(isVisible: isVisible)
    }
}

// Helper للـ Preview
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
