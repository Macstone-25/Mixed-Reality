import SwiftUI

@main
struct MixedRealityApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup(id: SceneID.windowGroup.rawValue) {
             StartView(appModel)
                 .environment(appModel)
        }
        .defaultSize(CGSize(width: 600, height: 350))
        .onChange(of: appModel.activeScene) { _, activeScene in
            Task {
                switch(activeScene) {
                case(.immersiveSpace):
                    let result = await openImmersiveSpace(id: SceneID.immersiveSpace.rawValue)
                    switch result {
                    case .opened:
                        print("Opened immersive space")
                        dismissWindow(id: SceneID.windowGroup.rawValue)
                    default:
                        print("Failed to open immersive space")
                        appModel.endSession()
                    }
                case(.windowGroup):
                    await dismissImmersiveSpace()
                    openWindow(id: SceneID.windowGroup.rawValue)
                    print("Dismissed immersive space")
                }
            }
        }

        ImmersiveSpace(id: SceneID.immersiveSpace.rawValue) {
            SessionView(appModel)
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
