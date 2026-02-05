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
}
