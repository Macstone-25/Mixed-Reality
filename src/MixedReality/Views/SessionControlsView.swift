import SwiftUI

struct SessionControlsView: View {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    @State private var viewModel: SessionControlsViewModel
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
        _viewModel = State(wrappedValue: SessionControlsViewModel(appModel: appModel, sessionViewModel: sessionViewModel))
    }

    var body: some View {
        HStack(spacing: 14) {
            if appModel.isEndingSession {
                Text("Ending session...")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(alignment: .center)
            } else {
                Text(viewModel.timeString)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(minWidth: 60, alignment: .leading)
                
                Spacer()
                
                Button(action: viewModel.onStop) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .glassBackgroundEffect()
        .frame(width: 240)
        .opacity(viewModel.isVisible ? 1: 0)
        .animation(.easeIn(duration: 0.5), value: viewModel.isVisible)
        .onAppear(perform: viewModel.onAppear)
    }
}
