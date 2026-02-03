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

            Button(viewModel.isLaunching ? "Launching..." : "Start Session") {
                appModel.startSession()
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .glassBackgroundEffect()
            .controlSize(.extraLarge)
            .font(.extraLargeTitle2)
            .disabled(viewModel.isLaunching)

            if let error = appModel.launchError {
                Text(error)
                    .foregroundColor(.red)
                    .monospaced()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 100)
        .padding(.bottom, 128)
        // reduced top padding due to navigation buttons
        .padding(.top, 64)
    }
}

#Preview {
    NavigationView(AppModel(), initView: .startView)
        .background(.regularMaterial)
        .glassBackgroundEffect()
}
