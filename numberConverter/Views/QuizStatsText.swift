//
//  QuizStatsText.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - QuizStatsText

/// composes the localized statistics line «Всего вопросов: X, из них правильно: Y»
/// shared by the per-quiz alert and the overall statistics screen.
enum QuizStatsText {
    static func message(asked: Int, right: Int) -> String {
        String(localized: "quiz.stats.message \(asked) \(right)")
    }
}
