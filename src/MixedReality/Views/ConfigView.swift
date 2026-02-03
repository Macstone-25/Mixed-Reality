//
//  ConfigView.swift
//  MixedReality
//

import SwiftUI

struct ConfigView: View {
    private let appModel: AppModel
    
    @State private var viewModel: ConfigViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: ConfigViewModel(appModel))
    }
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    NavigationView(AppModel(), initView: .configView)
        .background(.regularMaterial)
        .glassBackgroundEffect()
}
