//
//  ConverterView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - ConverterView

/// root screen of the converter tab.
/// placeholder for now; phase 4 builds the real conversion ui.
struct ConverterView: View {
    var body: some View {
        ComingSoonView(
            titleKey: AppTab.converter.titleKey,
            systemImage: AppTab.converter.systemImage
        )
        .navigationTitle(Text(AppTab.converter.navigationTitleKey))
    }
}

#Preview {
    NavigationStack {
        ConverterView()
    }
}
