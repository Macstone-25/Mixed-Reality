//
//  NavigationView.swift
//  MixedReality
//

import SwiftUI

struct NavigationView: View {
    private let appModel: AppModel
    
    @State private var viewModel: NavigationViewModel
    @State private var showSaveConfirmation = false
    @State private var saveConfirmationTask: Task<Void, Never>?
    
    let navButtonSize: CGFloat = 48
    
    init(_ appModel: AppModel, initView: WindowView = .startView) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: NavigationViewModel(appModel, initView: initView))
    }
    
    var body: some View {
        VStack {
            // navigation bar
            HStack {
                Button(action: viewModel.leftAction) {
                    Image(systemName: viewModel.leftIcon)
                        .frame(width: navButtonSize, height: navButtonSize)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                
                Spacer()
                
                Text(viewModel.title)
                    .font(.largeTitle)
                
                Spacer()
                
                if viewModel.rightIcon != "" {
                    Button(action: viewModel.rightAction) {
                        Image(systemName: viewModel.rightIcon)
                            .frame(width: navButtonSize, height: navButtonSize)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(.circle)
                } else {
                    Color.clear
                        .frame(width: navButtonSize, height: navButtonSize)
                }
            }
            
            Spacer()
            
            // content
            switch viewModel.activeView {
            case .startView:
                StartView(appModel)
            case .configView:
                ConfigView(appModel, onSave: presentSaveConfirmation)
            case .exportView:
                ExportView(appModel)
            }
            
            Spacer()
        }
        .padding(24)
        .ornament(
            visibility: showSaveConfirmation ? .visible : .hidden,
            attachmentAnchor: .scene(.top),
            contentAlignment: .center
        ) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("Changes saved")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
            .allowsHitTesting(false)
        }
    }

    private func presentSaveConfirmation() {
        saveConfirmationTask?.cancel()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSaveConfirmation = true
        }

        saveConfirmationTask = Task {
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSaveConfirmation = false
                }
                saveConfirmationTask = nil
            }
        }
    }
}

#Preview {
    NavigationView(AppModel())
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}
