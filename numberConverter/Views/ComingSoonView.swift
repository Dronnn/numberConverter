//
//  ComingSoonView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ComingSoonView

/// shared placeholder shown by the not-yet-built tab screens.
/// later phases replace each screen's body with real content.
struct ComingSoonView: View {
    let titleKey: LocalizedStringResource
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(titleKey)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            Text("placeholder.comingSoon")
        }
    }
}

#Preview {
    ComingSoonView(titleKey: "tab.converter", systemImage: "arrow.left.arrow.right")
}
