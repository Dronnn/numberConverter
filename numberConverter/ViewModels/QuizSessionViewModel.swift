//
//  QuizSessionViewModel.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation
import OSLog

// MARK: - QuizFeedback

/// the result of checking the user's answer, used to drive the feedback alert.
enum QuizFeedback: Equatable {
    case correct
    /// wrong, carrying the engine's canonical answer to reveal to the user.
    case wrong(correctAnswer: String)
}

// MARK: - QuizSessionViewModel

/// view model for one quiz session: it generates questions for a category,
/// checks the user's typed answer by value (not by re-conversion), and records
/// statistics. answer checking parses the input in the target base and compares
/// the exact decimal value, so equal forms (trailing zeros, hex letter case)
/// are accepted and wrong values rejected.
@Observable
@MainActor
final class QuizSessionViewModel {
    let category: QuizCategory

    private(set) var question: QuizQuestion
    var answer = ""
    private(set) var feedback: QuizFeedback?

    private let stats: QuizStats
    private let randomValue: () -> Decimal

    /// guards the per-question right-counter so re-tapping «Проверить» after a
    /// correct answer does not double-count.
    private var didCountRight = false

    /// - Parameter randomValue: injectable value generator; tests pass a fixed
    ///   value, production uses `Int.random` / a random dyadic fraction.
    init(
        category: QuizCategory,
        stats: QuizStats = QuizStats(),
        randomValue: (() -> Decimal)? = nil
    ) {
        self.category = category
        self.stats = stats
        self.randomValue = randomValue ?? { Self.randomValue(fraction: category.isFraction) }
        question = Self.makeQuestion(
            category: category,
            value: self.randomValue()
        )
        stats.recordAsked(category)
        AppLogger.quiz.info("started quiz \(category.rawValue, privacy: .public)")
    }

    // MARK: Question flow

    /// generates the next question, clears the answer and feedback, and records
    /// that a new question was asked.
    func nextQuestion() {
        question = Self.makeQuestion(category: category, value: randomValue())
        answer = ""
        feedback = nil
        didCountRight = false
        stats.recordAsked(category)
    }

    /// checks the current answer by value and records a correct answer once.
    func check() {
        if isCorrect(answer) {
            feedback = .correct
            if !didCountRight {
                didCountRight = true
                stats.recordRight(category)
            }
        } else {
            feedback = .wrong(correctAnswer: question.expectedAnswer)
        }
    }

    /// clears the feedback (the alert was dismissed).
    func dismissFeedback() {
        feedback = nil
    }

    // MARK: Statistics readout

    /// questions asked in this quiz so far (for the «Статистика» alert).
    var statsAsked: Int {
        stats.asked(category)
    }

    /// questions answered correctly in this quiz so far.
    var statsRight: Int {
        stats.right(category)
    }

    // MARK: Answer checking

    /// parses `input` in the target base and compares its exact value to the
    /// expected value; non-parsing or unequal input is wrong.
    private func isCorrect(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let value = ConversionEngine.toDecimal(trimmed, fromBase: question.direction.target) else {
            return false
        }
        return value == question.expectedValue
    }

    // MARK: Question construction

    /// builds a question for `value`: renders it in the source base (displayed)
    /// and the target base (expected answer), picking a random direction.
    private static func makeQuestion(category: QuizCategory, value: Decimal) -> QuizQuestion {
        let direction = category.directions.randomElement() ?? QuizDirection(source: 10, target: 2)
        let displayed = ConversionEngine.fromDecimal(value, toBase: direction.source) ?? "0"
        let expected = ConversionEngine.fromDecimal(value, toBase: direction.target) ?? "0"
        return QuizQuestion(
            direction: direction,
            displayed: displayed,
            expectedAnswer: expected,
            expectedValue: value
        )
    }

    // MARK: Value generation

    /// a random value for a question: an integer `0...999`, or a dyadic
    /// fraction `k / 2^m` (odd `k`, `1 ≤ m ≤ 6`) that terminates in ≤ six
    /// digits in every base — so every direction yields a short exact answer.
    private static func randomValue(fraction: Bool) -> Decimal {
        guard fraction else {
            return Decimal(Int.random(in: 0 ... 999))
        }
        let m = Int.random(in: 1 ... 6)
        let denominator = 1 << m
        let k = Self.randomOdd(below: denominator)
        return Decimal(k) / Decimal(denominator)
    }

    /// a random odd integer in `1 ..< limit` (limit is a power of two ≥ 2).
    private static func randomOdd(below limit: Int) -> Int {
        let value = Int.random(in: 1 ..< limit)
        return value | 1
    }
}
