import SwiftUI

struct StartView: View {
    private let appModel: AppModel
    
    @State private var viewModel: StartViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: StartViewModel(appModel: appModel))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Push the button below to begin.")
                .font(.title)
                .multilineTextAlignment(.center)

            Button("Start Session") {
                appModel.startSession()
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .glassBackgroundEffect()
            .controlSize(.extraLarge)
            .font(.extraLargeTitle2)
            .disabled(viewModel.isLaunching)
            // account for navigation buttons
            .padding(.bottom, 48)

            if let error = appModel.launchError {
                Text(error)
                    .foregroundColor(.red)
                    .monospaced()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let prevSession = appModel.lastSessionId {
                Text("Previous: \(prevSession)")
                    .monospaced()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView(AppModel(), initView: .startView)
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}
