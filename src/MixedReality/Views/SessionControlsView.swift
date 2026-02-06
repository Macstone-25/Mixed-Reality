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
        // Scale up proportionally 
        let baseFont: CGFloat = 17
        let targetFont: CGFloat = 30
        let scale = targetFont / baseFont

        let hPad = 18 * scale
        let vPad = 10 * scale

        if appModel.isEndingSession {
            Text("Ending session...")
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
                    Text("Stop Session")
                }
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(Color.red, in: Capsule())
            .opacity(viewModel.isVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: viewModel.isVisible)

        }
    }

}
