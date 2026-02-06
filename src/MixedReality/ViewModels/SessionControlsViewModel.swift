import Foundation

@MainActor
@Observable
class SessionControlsViewModel {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel

    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
    }

    var isVisible: Bool {
        !appModel.isLaunchingSession && appModel.session != nil
    }

    func onStop() {
        appModel.session?.onPrompt = nil
        sessionViewModel.prompt = ""
        appModel.endSession()
    }
}
