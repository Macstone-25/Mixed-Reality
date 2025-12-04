import SwiftUI
import AVFoundation  

struct StartView: View {
    @Environment(AppModel.self) private var appModel
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Ready to begin?")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)

            Button("Start Session") {
                requestMicPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("start-session-button")

            if let error = appModel.lastSessionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestMicPermission() {
        let session = AVAudioSession.sharedInstance()

        switch session.recordPermission {
        case .granted:
            // Already allowed – go ahead and start
            onStart()

        case .denied:
            // User has previously denied
            appModel.lastSessionError =
            "Microphone access is required. Please enable it in Settings."

        case .undetermined:
            // First time – ask
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.onStart()
                    } else {
                        self.appModel.lastSessionError =
                        "Microphone access is required. Please enable it in Settings."
                    }
                }
            }

        @unknown default:
            appModel.lastSessionError = "Unknown microphone permission state."
        }
    }
}
