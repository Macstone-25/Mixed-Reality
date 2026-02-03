//
//  ConfigViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class ConfigViewModel {
    private let appModel: AppModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
    }
}
