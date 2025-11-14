import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        RealityView { content, attachments in
            let headAnchor = AnchorEntity(.head)
            headAnchor.anchoring.trackingMode = .continuous
            content.add(headAnchor)
            
            if let uiAttachmentEntity = attachments.entity(for: "sessionControls") {
                uiAttachmentEntity.transform.translation = [0, -0.25, -0.70]
                headAnchor.addChild(uiAttachmentEntity)
            }
            
            if let uiAttachmentEntity = attachments.entity(for: "prompts") {
                uiAttachmentEntity.transform.translation = [0, 0.25, -0.70]
                headAnchor.addChild(uiAttachmentEntity)
            }
        } attachments: {
            Attachment(id: "sessionControls") {
                SessionControlsView(
                    elapsedTime: elapsedTime,
                    onStop: endSession
                )
            }
            Attachment(id: "prompts") {
                if appModel.prompt != "LISTENING" {
                    PromptView()
                }
            }
        }
        .onAppear {
            startSession()
        }
    }

    private func startSession() {
        guard appModel.isSessionActive else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func endSession() {
        print("Ending session...")
        timer?.invalidate()
        timer = nil
        appModel.endSession()
        Task {
            await dismissImmersiveSpace()
            openWindow(id: appModel.windowGroupId)
            print("Dismissed immersive space")
        }
    }
}
