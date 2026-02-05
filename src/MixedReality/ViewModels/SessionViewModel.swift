//
//  SessionViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class SessionViewModel {
    private let appModel: AppModel
    
    var prompt: String = ""
    
    init(appModel: AppModel) {
        self.appModel = appModel
    }
    
    func onAppear() {
        appModel.session?.onPrompt = { [weak self] prompt in
            guard let self = self else { return }
            self.prompt = prompt
        }
    }
    
    // MARK: - Prompt Read Tracking
    
    func logPromptRead(method: PromptReadMethod) {
        appModel.session?.logPromptRead(method: method)
    }
    
    func clearPrompt() {
        appModel.session?.logPromptDismissed()
        prompt = ""
    }
    
    func hasPromptBeenRead() -> Bool {
        return appModel.session?.hasPromptBeenRead() ?? false
    }
}
