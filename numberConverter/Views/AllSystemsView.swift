//
//  AllSystemsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - AllSystemsView

/// root screen of the all-systems tab.
/// placeholder for now; phase 4 builds the real all-systems ui.
struct AllSystemsView: View {
    var body: some View {
        ComingSoonView(
            titleKey: AppTab.allSystems.titleKey,
            systemImage: AppTab.allSystems.systemImage
        )
        .navigationTitle(Text(AppTab.allSystems.navigationTitleKey))
    }
}

#Preview {
    NavigationStack {
        AllSystemsView()
    }
}
