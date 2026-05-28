//
//  ShakeDetecting.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import SwiftUI
import UIKit

struct ShakeDetecting: UIViewControllerRepresentable {
    var onShake: () -> Void

    // Nested so the private type doesn't leak into the conformance signature.
    // Becomes first responder on appear so UIKit routes motion events here.
    final class Controller: UIViewController {
        var onShake: () -> Void = {}

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            onShake()
        }
    }

    func makeUIViewController(context: Context) -> Controller {
        let vc = Controller()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.onShake = onShake
    }
}

extension View {
    // Attach a zero-size shake detector to any view.
    func onShake(perform action: @escaping () -> Void) -> some View {
        background(ShakeDetecting(onShake: action).frame(width: 0, height: 0))
    }
}
