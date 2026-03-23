import SwiftUI
import OSLog

@main
struct MixedRealityApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup(id: SceneID.windowGroup.rawValue) {
             NavigationView(appModel)
                 .environment(appModel)
                 .task {
                     appModel.prewarmAudioIfNeeded()
                 }
        }
        .defaultSize(width: 750, height: 500)
        .defaultWindowPlacement { _, context in
            return WindowPlacement(.utilityPanel)
        }
        .onChange(of: appModel.activeScene) { _, activeScene in
            Task {
                switch(activeScene) {
                case(.immersiveSpace):
                    await openImmersiveForSession()
                case(.windowGroup):
                    await showWindowGroup()
                }
            }
        }
        .onChange(of: appModel.immersiveOpenRequest) { _, _ in
            guard appModel.session != nil && appModel.activeScene == .immersiveSpace else { return }
            Task {
                await openImmersiveForSession()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            appModel.restoreSessionAfterForegrounding()
        }

        ImmersiveSpace(id: SceneID.immersiveSpace.rawValue) {
            SessionView(appModel)
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }

    private func openImmersiveForSession() async {
        let result = await openImmersiveSpace(id: SceneID.immersiveSpace.rawValue)
        switch result {
        case .opened:
            appModel.logger.info("Opened immersive space")
            dismissWindow(id: SceneID.windowGroup.rawValue)
        default:
            appModel.logger.error("Failed to open immersive space")
            appModel.endSession()
        }
    }

    private func showWindowGroup() async {
        await dismissImmersiveSpace()
        openWindow(id: SceneID.windowGroup.rawValue)
        appModel.logger.info("Dismissed immersive space")
    }
}
