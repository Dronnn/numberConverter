//
//  QuizMenuView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - QuizMenuView

/// root screen of the quiz tab.
/// placeholder for now; a later phase builds the real quiz menu.
struct QuizMenuView: View {
    var body: some View {
        ComingSoonView(
            titleKey: AppTab.quiz.titleKey,
            systemImage: AppTab.quiz.systemImage
        )
        .navigationTitle(Text(AppTab.quiz.navigationTitleKey))
    }
}

#Preview {
    NavigationStack {
        QuizMenuView()
    }
}
