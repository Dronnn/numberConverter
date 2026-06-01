//
//  QuizStatsViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import OSLog

// MARK: - QuizStatsRow

/// one row of the statistics screen: a title key and its asked/right counts.
struct QuizStatsRow: Identifiable {
    let id: String
    let titleKey: LocalizedStringResource
    let asked: Int
    let right: Int
}

// MARK: - QuizStatsViewModel

/// view model for the overall statistics screen: exposes the aggregate and the
/// eight per-quiz rows, and resets all counters.
@Observable
@MainActor
final class QuizStatsViewModel {
    private let stats: QuizStats

    /// bumped on reset so the view recomputes its rows.
    private(set) var version = 0

    init(stats: QuizStats = QuizStats()) {
        self.stats = stats
    }

    /// the overall aggregate row.
    var overall: QuizStatsRow {
        _ = version
        return QuizStatsRow(
            id: "all",
            titleKey: "quiz.stats.overall",
            asked: stats.allAsked,
            right: stats.allRight
        )
    }

    /// one row per quiz, in menu order.
    var rows: [QuizStatsRow] {
        _ = version
        return QuizCategory.allCases.map { category in
            QuizStatsRow(
                id: category.rawValue,
                titleKey: category.menuRowKey,
                asked: stats.asked(category),
                right: stats.right(category)
            )
        }
    }

    /// zeroes every counter and refreshes the rows.
    func reset() {
        stats.reset()
        version += 1
        AppLogger.quiz.info("stats reset")
    }
}
