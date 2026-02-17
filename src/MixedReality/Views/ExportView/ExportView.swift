//
//  ExportView.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-03.
//

import SwiftUI

struct ExportView: View {
    private let appModel: AppModel
    
    @StateObject private var viewModel: ExportViewModel
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
        _viewModel = StateObject(wrappedValue: ExportViewModel(appModel))
    }

    var body: some View {
        VStack(spacing: 24) {
            List(viewModel.sessions, selection: $viewModel.selection) { item in
                HStack {
                    Image(systemName: "folder")
                    Text(item.name)
                }
            }
            .environment(\.editMode, .constant(.active))
            .allowsHitTesting(!viewModel.isBusy)
            
            Text(viewModel.statusText)
            
            HStack {
                Button("Delete") {
                    viewModel.deleteData()
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .disabled(viewModel.actionsDisabled || !appModel.config.isDeleteEnabled)
                .allowsHitTesting(appModel.config.isDeleteEnabled)
                .opacity(appModel.config.isDeleteEnabled ? 1 : 0)
                
                Spacer()
                
                Button(viewModel.selection.count == viewModel.sessions.count ? "Deselect All" : "Select All") {
                    viewModel.selectAll()
                }
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .disabled(viewModel.isBusy)
                
                Button(action: viewModel.refreshFolders) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .clipShape(.circle)
                .disabled(viewModel.isBusy)
                
                Spacer()
                
                Button("Export") {
                    viewModel.exportData()
                }
                .tint(.blue)
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .disabled(viewModel.actionsDisabled)
            }
        }
        .overlay {
            if let zipURL = viewModel.zipURL {
                ActivityShareSheet(
                    item: zipURL,
                    onComplete: viewModel.cleanup
                )
            }
        }
        .onAppear(perform: viewModel.refreshFolders)
    }
}

#Preview {
    NavigationView(AppModel(), initView: .exportView)
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}
