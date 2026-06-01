//
//  HelpIndexView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - HelpIndexView

/// root screen of the info/help tab.
/// placeholder for now; a later phase builds the real help index.
struct HelpIndexView: View {
    var body: some View {
        ComingSoonView(
            titleKey: AppTab.info.titleKey,
            systemImage: AppTab.info.systemImage
        )
        .navigationTitle(Text(AppTab.info.navigationTitleKey))
    }
}

#Preview {
    NavigationStack {
        HelpIndexView()
    }
}
