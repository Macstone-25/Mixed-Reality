import SwiftUI

@main
struct MixedRealityApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.hasConsented {
            ContentView()
        } else {
            ConsentView(onAccept: { appState.hasConsented = true })
        }
    }
}
