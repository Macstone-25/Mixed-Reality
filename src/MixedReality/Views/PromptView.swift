//
//  PromptView.swift
//  MixedReality
//
//  Created by William Clubine on 2025-11-14.
//

import SwiftUI

struct PromptView: View {
    @Environment(AppModel.self) private var appModel

    // Initialize independently of @Environment
    @State private var isVisible: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Text(appModel.prompt)

            Button(action: clearPrompt) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .glassBackgroundEffect()
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: isVisible)
        .onAppear {
            // Safe to read @Environment now
            isVisible = !appModel.prompt.isEmpty
        }
        .onChange(of: appModel.prompt) { _, newValue in
            isVisible = !newValue.isEmpty
        }
    }

    private func clearPrompt() {
        appModel.prompt = ""
    }
}

#Preview {
    PromptView()
}
