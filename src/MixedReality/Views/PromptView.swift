//
//  PromptView.swift
//  MixedReality
//

import SwiftUI

struct PromptView: View {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    @State private var viewModel: PromptViewModel
    @FocusState private var isFocused: Bool
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
        _viewModel = State(wrappedValue: PromptViewModel(appModel: appModel, sessionViewModel: sessionViewModel))
    }

    var body: some View {
        VStack(spacing: 10) {
            // Wrap entire prompt in a large Button for reliable gaze detection
            Button(action: {
                // Button tap dismisses (same as checkmark)
                viewModel.confirmReadAndClear()
            }) {
                HStack(spacing: 14) {
                    Text(sessionViewModel.prompt)
                        .multilineTextAlignment(.leading)

                    // Visual checkmark indicator (non-interactive, just visual)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(minWidth: 350, minHeight: 100)  // Large hit area for eye tracking
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .focusable(true)
            .focused($isFocused)
            .background(.regularMaterial, in: Capsule())
            .glassBackgroundEffect()
            .hoverEffect()  // Enable system hover effect
            .onChange(of: isFocused) { _, focused in
                viewModel.updateGazeSignal(isFocused: focused)
            }
            .onHover { hovering in
                viewModel.updateGazeSignal(isHovering: hovering)
            }
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: viewModel.isVisible)
            .onChange(of: sessionViewModel.prompt) { _, _ in
                viewModel.onPromptChanged()
            }
            
            if viewModel.isVisible && viewModel.isGazeActive {
                ProgressView(value: viewModel.gazeProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 240)
            }
        }
    }
}
