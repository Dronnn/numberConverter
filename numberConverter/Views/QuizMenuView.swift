//
//  QuizMenuView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - QuizDestination

/// the screens pushed from the quiz menu: a session for a quiz, or the stats.
enum QuizDestination: Hashable {
    case session(QuizCategory)
    case statistics
}

// MARK: - QuizMenuView

/// root screen of the quiz tab: the eight quizzes plus the overall-statistics row.
struct QuizMenuView: View {
    var body: some View {
        List {
            Section {
                ForEach(QuizCategory.allCases) { category in
                    NavigationLink(value: QuizDestination.session(category)) {
                        Text(category.menuRowKey)
                    }
                }
                NavigationLink(value: QuizDestination.statistics) {
                    Text("quiz.menu.row9")
                }
            } header: {
                Text("quiz.menu.sectionHeader")
            }
        }
        .navigationTitle(Text(AppTab.quiz.navigationTitleKey))
        .onAppear { AppLogger.quiz.screen("quizMenu") }
        .navigationDestination(for: QuizDestination.self) { destination in
            switch destination {
            case let .session(category):
                QuizSessionView(category: category)
            case .statistics:
                QuizStatsView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        QuizMenuView()
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
