import SwiftUI
import AVFoundation  

struct StartView: View {
    private let appModel: AppModel
    
    @State private var viewModel: StartViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: StartViewModel(appModel: appModel))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Ready to begin?")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)

            let isSessionActive = appModel.isLaunchingSession || appModel.session != nil
            Button(isSessionActive ? "Launching..." : "Start Session") {
                appModel.startSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("start-session-button")
            .disabled(appModel.isLaunchingSession)

            if let error = appModel.launchError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
