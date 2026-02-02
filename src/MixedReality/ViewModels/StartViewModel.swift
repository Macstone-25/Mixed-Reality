//
//  StartViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class StartViewModel {
    private let appModel: AppModel
    
    // TODO: state / logic for entering data export / experiment config (#48 / #47)
    
    init(appModel: AppModel) {
        self.appModel = appModel
    }
}
