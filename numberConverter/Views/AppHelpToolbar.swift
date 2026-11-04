//
//  AppHelpToolbar.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

private struct AppHelpToolbar: ViewModifier {
    @Environment(AppNavigationState.self) private var navigation: AppNavigationState?
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            if isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigation?.presentHelp()
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .disabled(navigation == nil)
                    .accessibilityLabel(Text("help.open"))
                    .accessibilityIdentifier("app.help")
                }
            }
        }
    }
}

private struct HelpCloseToolbar: ViewModifier {
    @Environment(AppNavigationState.self) private var navigation: AppNavigationState?
    @Environment(\.dismiss) private var dismiss
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            if isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let navigation {
                            navigation.isShowingHelp = false
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(Text("help.close"))
                    .accessibilityIdentifier("help.close")
                }
            }
        }
    }
}

extension View {
    func appHelpToolbar(isEnabled: Bool = true) -> some View {
        modifier(AppHelpToolbar(isEnabled: isEnabled))
    }

    func helpCloseToolbar(isEnabled: Bool = true) -> some View {
        modifier(HelpCloseToolbar(isEnabled: isEnabled))
    }
}
