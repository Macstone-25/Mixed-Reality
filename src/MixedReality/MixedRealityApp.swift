import SwiftUI

enum SceneID: String {
    case immersiveSpace = "ImmersiveSpace"
    case windowGroup = "DefaultWindowGroup"
}

@main
struct MixedRealityApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup(id: SceneID.windowGroup.rawValue) {
             ContentView()
                 .environment(appModel)
        }
        .defaultSize(CGSize(width: 600, height: 350))

        // Immersive space left as-is (not used by the demo window)
        ImmersiveSpace(id: SceneID.immersiveSpace.rawValue) {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
