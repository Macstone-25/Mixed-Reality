//
//  PromptView.swift
//  MixedReality
//

import SwiftUI

struct PromptView: View {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    @State private var viewModel: PromptViewModel
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
        _viewModel = State(wrappedValue: PromptViewModel(appModel: appModel, sessionViewModel: sessionViewModel))
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(sessionViewModel.prompt)

            Button(action: { sessionViewModel.prompt = "" }) {
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
        .opacity(viewModel.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: viewModel.isVisible)
    }
}
