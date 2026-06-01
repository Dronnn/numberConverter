//
//  QuizStats.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - QuizStats

/// the quiz statistics store: per-quiz *asked* / *right* counters plus an `all`
/// aggregate, persisted under the legacy UserDefaults keys. tests inject an
/// isolated suite so they never touch the real defaults.
struct QuizStats {
    /// legacy keys for the overall aggregate counters.
    static let allAskedKey = "allQuestionCount"
    static let allRightKey = "allQuestionRightCount"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Reads

    /// number of questions asked in a quiz.
    func asked(_ category: QuizCategory) -> Int {
        defaults.integer(forKey: category.askedKey)
    }

    /// number of questions answered correctly in a quiz.
    func right(_ category: QuizCategory) -> Int {
        defaults.integer(forKey: category.rightKey)
    }

    /// total questions asked across every quiz.
    var allAsked: Int {
        defaults.integer(forKey: Self.allAskedKey)
    }

    /// total questions answered correctly across every quiz.
    var allRight: Int {
        defaults.integer(forKey: Self.allRightKey)
    }

    // MARK: Writes

    /// records that a new question was asked: bumps the quiz and the aggregate.
    func recordAsked(_ category: QuizCategory) {
        increment(category.askedKey)
        increment(Self.allAskedKey)
    }

    /// records a correct answer: bumps the quiz and the aggregate.
    func recordRight(_ category: QuizCategory) {
        increment(category.rightKey)
        increment(Self.allRightKey)
    }

    /// zeroes all eighteen counters (eight quizzes × two + the aggregate pair).
    func reset() {
        for category in QuizCategory.allCases {
            defaults.removeObject(forKey: category.askedKey)
            defaults.removeObject(forKey: category.rightKey)
        }
        defaults.removeObject(forKey: Self.allAskedKey)
        defaults.removeObject(forKey: Self.allRightKey)
    }

    // MARK: Private

    private func increment(_ key: String) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }
}
