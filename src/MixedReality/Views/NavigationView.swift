//
//  NavigationView.swift
//  MixedReality
//

import SwiftUI

struct NavigationView: View {
    private let appModel: AppModel
    
    @State private var viewModel: NavigationViewModel
    
    let navButtonSize: CGFloat = 64
    
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
                        .font(.title)
                        .frame(width: navButtonSize, height: navButtonSize)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial)
                .glassBackgroundEffect()
                .clipShape(Circle())
                
                Spacer()
                
                Text(viewModel.title)
                    .font(.largeTitle)
                
                Spacer()
                
                if viewModel.rightIcon != "" {
                    Button(action: viewModel.rightAction) {
                        Image(systemName: viewModel.rightIcon)
                            .font(.title)
                            .frame(width: navButtonSize, height: navButtonSize)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                    .glassBackgroundEffect()
                    .clipShape(Circle())
                } else {
                    Color.clear
                        .frame(width: navButtonSize, height: navButtonSize)
                }
            }
            
            // content
            switch viewModel.activeView {
            case .startView:
                StartView(appModel)
            case .configView:
                ConfigView(appModel)
            case .exportView:
                Text("TODO: export view")
            }
        }
        .frame(width: 700)
        .padding(16)
    }
}

#Preview {
    NavigationView(AppModel())
        .background(.regularMaterial)
        .glassBackgroundEffect()
}
