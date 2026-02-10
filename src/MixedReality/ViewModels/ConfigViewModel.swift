//
//  ConfigViewModel.swift
//  MixedReality
//

import Foundation
import Combine

@MainActor
class ConfigViewModel: ObservableObject {
    private let appModel: AppModel
    
    @Published var config: ConfigModel
    
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
