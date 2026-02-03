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
            
            Text(viewModel.statusText)
            
            HStack {
                Button("Delete") {
                    // TODO: Enable this functionality once cloud upload is working (#42)
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                .disabled(true) // viewModel.actionsDisabled
                
                Spacer()
                
                Button(viewModel.selection.count == viewModel.sessions.count ? "Deselect All" : "Select All") {
                    viewModel.selectAll()
                }
                .buttonStyle(.borderedProminent)
                .glassBackgroundEffect()
                
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
        .onAppear {
            DispatchQueue.main.async {
                viewModel.refreshFolders()
            }
        }
    }
}

#Preview {
    NavigationView(AppModel(), initView: .exportView)
        .background(.thinMaterial)
        .frame(maxWidth: 750, maxHeight: 500)
        .glassBackgroundEffect()
}
