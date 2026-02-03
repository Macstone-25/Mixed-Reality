//
//  ConfigViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class ConfigViewModel {
    private let appModel: AppModel
    
    var config: ConfigModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        config = appModel.config
    }
    
    func applyChanges() {
        appModel.config = config
        appModel.config.save()
    }
    
    func undoChanges() {
        config = appModel.config
    }
    
    func resetConfig() {
        config = ConfigModel.default
    }
}
