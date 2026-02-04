//
//  NavigationViewModel.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-02.
//

import Foundation

/// Views that could be displayed on the primary window
enum WindowView {
    case startView
    case configView
    case exportView
}

@MainActor
@Observable
class NavigationViewModel {
    private let appModel: AppModel
    
    var activeView: WindowView
    
    init(_ appModel: AppModel, initView: WindowView = .startView) {
        self.appModel = appModel
        self.activeView = initView
    }
    
    var title: String {
        switch activeView {
        case .startView:
            ""
        case .configView:
            "Experiment Configuration"
        case .exportView:
            "Data Export"
        }
    }
    
    var leftIcon: String {
        switch activeView {
        case .startView:
            "gearshape.fill"
        default:
            "chevron.backward"
        }
    }
    
    /// Navigates either back (default) or to the config view (from the start view)
    func leftAction() {
        activeView = activeView == .startView ? .configView : .startView
    }
    
    var rightIcon: String {
        switch activeView {
        case .startView:
            "square.and.arrow.up.fill"
        default:
            ""
        }
    }
    
    /// Navigates to the export view (only from the start view)
    func rightAction() {
        guard activeView == .startView else { return }
        activeView = .exportView
    }
}
