//
//  PromptView.swift
//  MixedReality
//
//  Created by William Clubine on 2025-11-14.
//

import SwiftUI

struct PromptView: View {
    @Environment(AppModel.self) private var appModel
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 14) {
            Text(appModel.prompt)
            
            Button(action: clearPrompt) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "checkmark.fill")
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
            .opacity(isVisible ? 1: 0)
            .animation(.easeIn(duration: 0.5), value: isVisible)
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
            }
    }
    
    private func clearPrompt() {
        appModel.prompt = "LISTENING"
    }
}

#Preview {
    PromptView()
}
