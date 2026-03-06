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
        let hPad: CGFloat = 32
        let vPad: CGFloat = 18
        
        let sessionLabel: String = appModel.lastSessionId ?? "Session"
        
        if appModel.isEndingSession {
            Text("Ending \(sessionLabel)...")
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(.regularMaterial, in: Capsule())
                .glassBackgroundEffect()
                .opacity(viewModel.isVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: viewModel.isVisible)
        } else {
            Button(action: viewModel.onStop) {
                HStack(spacing: 12) {
                    Image(systemName: "stop.circle.fill")
                        .symbolRenderingMode(.monochrome)
                    Text("Stop \(sessionLabel)")
                }
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
            }
            .buttonStyle(.plain)
            .background(Color.red, in: Capsule())
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: viewModel.isVisible)
        }
    }
}
