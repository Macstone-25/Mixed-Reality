//
//  PromptViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class PromptViewModel {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
    }
    
    var isVisible: Bool {
        !sessionViewModel.prompt.isEmpty
    }
}
