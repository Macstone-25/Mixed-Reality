import SwiftUI

struct StartView: View {
    @Environment(AppModel.self) private var appModel
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Ready to begin?")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)

            Button("Start Session") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("start-session-button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
