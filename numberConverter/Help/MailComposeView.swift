//
//  MailComposeView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import MessageUI
import SwiftUI

// MARK: - MailComposeView

/// the single allowed uikit drop: wraps `MFMailComposeViewController` so the
/// help index can offer a "write to the developers" mail composer.
struct MailComposeView: UIViewControllerRepresentable {
    /// developer contact carried over from the legacy app.
    static let recipient = "vanyurin@me.com"
    static let subject = "Обращение по поводу приложения Системы счисления"

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([Self.recipient])
        controller.setSubject(Self.subject)
        return controller
    }

    func updateUIViewController(_: MFMailComposeViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}
