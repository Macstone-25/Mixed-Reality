//
//  NavigationView.swift
//  MixedReality
//

import SwiftUI

struct NavigationView: View {
    private let appModel: AppModel
    
    @State private var viewModel: NavigationViewModel
    
    let navButtonSize: CGFloat = 48
    
    init(_ appModel: AppModel, initView: WindowView = .startView) {
        self.appModel = appModel
        _viewModel = State(wrappedValue: NavigationViewModel(appModel, initView: initView))
    }
    
    var body: some View {
        VStack {
            // navigation bar
            HStack {
                Button(action: viewModel.leftAction) {
                    Image(systemName: viewModel.leftIcon)
                        .frame(width: navButtonSize, height: navButtonSize)
                }
                .buttonStyle(.plain)
                .glassBackgroundEffect()
                .background(.thickMaterial)
                .clipShape(.circle)
                
                Spacer()
                
                Text(viewModel.title)
                    .font(.largeTitle)
                
                Spacer()
                
                if viewModel.rightIcon != "" {
                    Button(action: viewModel.rightAction) {
                        Image(systemName: viewModel.rightIcon)
                            .frame(width: navButtonSize, height: navButtonSize)
                    }
                    .buttonStyle(.plain)
                    .glassBackgroundEffect()
                    .background(.thickMaterial)
                    .clipShape(.circle)
                } else {
                    Color.clear
                        .frame(width: navButtonSize, height: navButtonSize)
                }
            }
            
            Spacer()
            
            // content
            switch viewModel.activeView {
            case .startView:
                StartView(appModel)
            case .configView:
                ConfigView(appModel)
            case .exportView:
                ExportView(appModel)
            }
            
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    NavigationView(AppModel())
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}
