import SwiftUI

@main
struct MixedRealityApp: App {
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup(id: appModel.windowGroupId) {
            // ORIGINAL (temporarily disabled for testing):
             ContentView()
                 .environment(appModel)

            // TEST VIEW (enable this to exercise the trigger engine demo):
//            TriggerDemoView(useLLM: false)   // flip to true to test LLM-augmented mode
//                .environment(appModel)
        }
        .defaultSize(CGSize(width: 600, height: 350))

        // Immersive space left as-is (not used by the demo window)
        ImmersiveSpace(id: appModel.immersiveSpaceId) {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
