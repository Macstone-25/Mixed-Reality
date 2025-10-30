import SwiftUI

@main
struct MixedRealityApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup(id: appModel.windowGroupId) {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(CGSize(width: 600, height: 350))

        ImmersiveSpace(id: appModel.immersiveSpaceId) {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
