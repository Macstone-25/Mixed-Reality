import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        if !appModel.hasConsent {
            ConsentView {
                appModel.hasConsent = true
            }
        } else {
            StartView {
                appModel.startSession()
                Task {
                    let result = await openImmersiveSpace(id: appModel.immersiveSpaceId)
                    switch result {
                    case .opened:
                        print("Opened immersive space")
                        dismissWindow(id: appModel.windowGroupId)
                    default:
                        print("Failed to open immersive space")
                        appModel.isSessionActive = false
                    }
                }
            }
        }
    }
}
