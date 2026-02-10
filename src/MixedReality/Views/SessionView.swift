import SwiftUI
import RealityKit

struct SessionView: View {
    private let appModel: AppModel

    @State private var viewModel: SessionViewModel

    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: SessionViewModel(appModel: appModel))
    }

    var body: some View {
        RealityView { content, attachments in
            let headAnchor = AnchorEntity(.head)
            headAnchor.anchoring.trackingMode = .continuous
            content.add(headAnchor)

            if let uiAttachmentEntity = attachments.entity(for: "sessionControls") {
                uiAttachmentEntity.transform.translation = [0, 0.22, -0.58]
                headAnchor.addChild(uiAttachmentEntity)
            }

            if let uiAttachmentEntity = attachments.entity(for: "prompts") {
                uiAttachmentEntity.transform.translation = [0, -0.20, -0.58]
                headAnchor.addChild(uiAttachmentEntity)
            }
        } attachments: {
            Attachment(id: "sessionControls") {
                SessionControlsView(appModel: appModel, sessionViewModel: viewModel)
            }
            Attachment(id: "prompts") {
                PromptView(appModel: appModel, sessionViewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}
