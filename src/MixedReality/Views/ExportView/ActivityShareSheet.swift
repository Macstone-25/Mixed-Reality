//
//  ActivityShareSheet.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-03.
//

import SwiftUI
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let item: URL
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .clear
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard !context.coordinator.didPresent else { return }
        context.coordinator.didPresent = true

        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }

        if let popover = vc.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = host.view.bounds
            popover.permittedArrowDirections = []
        }

        host.present(vc, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var didPresent = false
    }
}
