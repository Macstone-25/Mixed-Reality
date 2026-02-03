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
    }
    
    func revertChanges() {
        config = appModel.config
    }
}
