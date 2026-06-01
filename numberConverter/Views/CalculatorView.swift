//
//  CalculatorView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - CalculatorView

/// root screen of the calculator tab.
/// placeholder for now; phase 5 builds the real calculator ui.
struct CalculatorView: View {
    var body: some View {
        ComingSoonView(
            titleKey: AppTab.calculator.titleKey,
            systemImage: AppTab.calculator.systemImage
        )
        .navigationTitle(Text(AppTab.calculator.navigationTitleKey))
    }
}

#Preview {
    NavigationStack {
        CalculatorView()
    }
}
