//
//  QuizSessionViewModelTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Foundation
@testable import numberConverter
import Testing

// MARK: - QuizSessionViewModelTests

@MainActor
final class QuizSessionViewModelTests {
    /// every isolated UserDefaults suite this test created, torn down at the end
    /// so the randomized direction-coverage tests cannot leak suites.
    private var createdSuiteNames: [String] = []

    deinit {
        for name in createdSuiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    /// an isolated stats store backed by an empty UserDefaults suite. the suite
    /// MUST be creatable — falling back to `.standard` would leak quiz counters
    /// into the user's real defaults, so a `nil` suite fails the test instead.
    private func makeStats() -> QuizStats {
        let suiteName = "quiz.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("could not create isolated UserDefaults suite \(suiteName)")
            // a fresh, empty in-memory placeholder so the test can continue to
            // its failing #expect rather than crashing on a force-unwrap.
            return QuizStats(defaults: UserDefaults())
        }
        defaults.removePersistentDomain(forName: suiteName)
        createdSuiteNames.append(suiteName)
        return QuizStats(defaults: defaults)
    }

    /// a direction picker that always returns the pinned direction, used to make
    /// a question deterministic. the picker is given the category's directions
    /// but we override with the exact pair under test.
    private func pin(_ source: Int, _ target: Int) -> ([QuizDirection]) -> QuizDirection {
        { _ in QuizDirection(source: source, target: target) }
    }

    private static let fractionCategories: [QuizCategory] =
        [.binaryFraction, .octalFraction, .decimalFraction, .hexFraction]

    private static let integerCategories: [QuizCategory] =
        [.binaryInt, .octalInt, .decimalInt, .hexInt]

    // MARK: Deterministic anchored questions (independent oracle)

    /// every expected string below is computed by hand, NOT by ConversionEngine:
    ///   255 = 11111111₂ = 377₈ = FF₁₆ ; 0.625 = 0.101₂ = 0.5₈ = 0.A₁₆.
    /// for direction (s → t) the displayed number is the value in base `s` and
    /// the expected answer is the value in base `t`.
    @Test
    func anchoredInteger255AcrossDirections() {
        let cases: [(QuizCategory, Int, Int, String, String)] = [
            (.decimalInt, 10, 2, "255", "11111111"),
            (.binaryInt, 2, 10, "11111111", "255"),
            (.hexInt, 16, 10, "FF", "255"),
            (.octalInt, 8, 10, "377", "255")
        ]
        for (category, source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: category,
                stats: makeStats(),
                randomValue: { Decimal(255) },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction.source == source)
            #expect(q.direction.target == target)
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
            #expect(q.expectedValue == Decimal(255))
        }
    }

    /// 0.625 = 5/8 = 0.101₂ = 0.5₈ = 0.A₁₆ = 0.625₁₀ (all hand-computed).
    @Test
    func anchoredFraction0625AcrossDirections() {
        let value = Decimal(5) / Decimal(8) // 0.625 exactly
        let cases: [(QuizCategory, Int, Int, String, String)] = [
            (.decimalFraction, 10, 2, "0.625", "0.101"),
            (.binaryFraction, 2, 10, "0.101", "0.625")
        ]
        for (category, source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: category,
                stats: makeStats(),
                randomValue: { value },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction.source == source)
            #expect(q.direction.target == target)
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
            #expect(q.expectedValue == value)
        }
    }

    /// all six directions of the binary quiz, pinned, with value 255.
    /// 255 = 11111111₂ = 377₈ = FF₁₆ = 255₁₀ (hand-computed).
    @Test
    func anchoredBinaryIntAllSixDirections() {
        // binaryInt directions: (2,10),(10,2),(8,2),(2,8),(16,2),(2,16).
        let cases: [(Int, Int, String, String)] = [
            (2, 10, "11111111", "255"),
            (10, 2, "255", "11111111"),
            (8, 2, "377", "11111111"),
            (2, 8, "11111111", "377"),
            (16, 2, "FF", "11111111"),
            (2, 16, "11111111", "FF")
        ]
        for (source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: .binaryInt,
                stats: makeStats(),
                randomValue: { Decimal(255) },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction == QuizDirection(source: source, target: target))
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
        }
    }

    /// all six directions of the hex quiz, pinned, with value 255.
    /// 255 = FF₁₆ = 255₁₀ = 11111111₂ = 377₈ (hand-computed).
    @Test
    func anchoredHexIntAllSixDirections() {
        // hexInt directions: (16,10),(10,16),(16,2),(2,16),(16,8),(8,16).
        let cases: [(Int, Int, String, String)] = [
            (16, 10, "FF", "255"),
            (10, 16, "255", "FF"),
            (16, 2, "FF", "11111111"),
            (2, 16, "11111111", "FF"),
            (16, 8, "FF", "377"),
            (8, 16, "377", "FF")
        ]
        for (source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: .hexInt,
                stats: makeStats(),
                randomValue: { Decimal(255) },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction == QuizDirection(source: source, target: target))
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
        }
    }

    /// all six directions of the binary fraction quiz, pinned, with value 0.625.
    /// 0.625 = 5/8 = 0.101₂ = 0.5₈ = 0.A₁₆ = 0.625₁₀ (hand-computed).
    @Test
    func anchoredBinaryFractionAllSixDirections() {
        let value = Decimal(5) / Decimal(8) // 0.625 exactly
        // binaryFraction directions: (2,10),(10,2),(8,2),(2,8),(16,2),(2,16).
        let cases: [(Int, Int, String, String)] = [
            (2, 10, "0.101", "0.625"),
            (10, 2, "0.625", "0.101"),
            (8, 2, "0.5", "0.101"),
            (2, 8, "0.101", "0.5"),
            (16, 2, "0.A", "0.101"),
            (2, 16, "0.101", "0.A")
        ]
        for (source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: .binaryFraction,
                stats: makeStats(),
                randomValue: { value },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction == QuizDirection(source: source, target: target))
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
        }
    }

    /// all six directions of the hex fraction quiz, pinned, with value 0.625.
    /// 0.625 = 5/8 = 0.A₁₆ = 0.625₁₀ = 0.101₂ = 0.5₈ (hand-computed).
    @Test
    func anchoredHexFractionAllSixDirections() {
        let value = Decimal(5) / Decimal(8) // 0.625 exactly
        // hexFraction directions: (16,10),(10,16),(16,2),(2,16),(16,8),(8,16).
        let cases: [(Int, Int, String, String)] = [
            (16, 10, "0.A", "0.625"),
            (10, 16, "0.625", "0.A"),
            (16, 2, "0.A", "0.101"),
            (2, 16, "0.101", "0.A"),
            (16, 8, "0.A", "0.5"),
            (8, 16, "0.5", "0.A")
        ]
        for (source, target, displayed, answer) in cases {
            let sut = QuizSessionViewModel(
                category: .hexFraction,
                stats: makeStats(),
                randomValue: { value },
                pickDirection: pin(source, target)
            )
            let q = sut.question
            #expect(q.direction == QuizDirection(source: source, target: target))
            #expect(q.displayed == displayed)
            #expect(q.expectedAnswer == answer)
        }
    }

    // MARK: Direction & answer correctness (round-trip across all directions)

    /// for every direction of every quiz, the displayed number and the expected
    /// answer are the same value rendered in the two bases, both finite and
    /// (for fractions) ≤ six fraction digits. proved by generating many
    /// questions so all six directions are exercised. one isolated suite per
    /// test (reused across iterations) so no suites leak.
    @Test
    func fractionAnswersAreFiniteAndCorrectAcrossDirections() {
        let stats = makeStats()
        for category in Self.fractionCategories {
            var seenDirections: Set<QuizDirection> = []
            for _ in 0 ..< 400 {
                let sut = QuizSessionViewModel(category: category, stats: stats)
                let q = sut.question
                seenDirections.insert(q.direction)

                // displayed and answer round-trip to the same exact value.
                let displayedValue = ConversionEngine.toDecimal(q.displayed, fromBase: q.direction.source)
                let answerValue = ConversionEngine.toDecimal(q.expectedAnswer, fromBase: q.direction.target)
                #expect(displayedValue == q.expectedValue)
                #expect(answerValue == q.expectedValue)

                // the answer is finite with at most six fraction digits.
                #expect(fractionDigitCount(q.expectedAnswer) <= 6)
                #expect(fractionDigitCount(q.displayed) <= 6)
            }
            #expect(seenDirections.count == 6)
        }
    }

    @Test
    func integerAnswersAreCorrectAcrossDirections() {
        let stats = makeStats()
        for category in Self.integerCategories {
            var seenDirections: Set<QuizDirection> = []
            for _ in 0 ..< 400 {
                let sut = QuizSessionViewModel(category: category, stats: stats)
                let q = sut.question
                seenDirections.insert(q.direction)

                let displayedValue = ConversionEngine.toDecimal(q.displayed, fromBase: q.direction.source)
                let answerValue = ConversionEngine.toDecimal(q.expectedAnswer, fromBase: q.direction.target)
                #expect(displayedValue == q.expectedValue)
                #expect(answerValue == q.expectedValue)
                // integers never have a fraction part.
                #expect(!q.expectedAnswer.contains("."))
            }
            #expect(seenDirections.count == 6)
        }
    }

    // MARK: Answer checking

    @Test
    func acceptsCanonicalAnswer() {
        let sut = QuizSessionViewModel(category: .decimalInt, stats: makeStats())
        sut.answer = sut.question.expectedAnswer
        sut.check()
        #expect(sut.feedback == .correct)
    }

    @Test
    func acceptsTrailingZeroForm() {
        // value 1/2 renders as a short fraction in every base; an equal form
        // with an extra trailing zero must still be accepted.
        let sut = QuizSessionViewModel(category: .decimalFraction, stats: makeStats()) {
            Decimal(1) / Decimal(2)
        }
        sut.answer = sut.question.expectedAnswer + "0"
        sut.check()
        #expect(sut.feedback == .correct)
    }

    @Test
    func acceptsHexCaseInsensitive() {
        // value 10/16 = 0.A in hex; pin the direction to a hex target so the
        // expected answer is "0.A", then assert a lowercase form is accepted.
        let sut = QuizSessionViewModel(
            category: .hexFraction,
            stats: makeStats(),
            randomValue: { Decimal(10) / Decimal(16) },
            pickDirection: pin(10, 16)
        )
        #expect(sut.question.direction.target == 16)
        #expect(sut.question.expectedAnswer == "0.A")
        sut.answer = "0.a"
        sut.check()
        #expect(sut.feedback == .correct)
    }

    @Test
    func rejectsWrongValueAndRevealsAnswer() {
        let sut = QuizSessionViewModel(category: .decimalInt, stats: makeStats())
        sut.answer = "definitely-not-a-number-#"
        sut.check()
        #expect(sut.feedback == .wrong(correctAnswer: sut.question.expectedAnswer))
    }

    @Test
    func rejectsNumericallyWrongAnswer() {
        // value 5 in direction 10 → 2 ; the correct answer is 101₂. an answer
        // of 10₂ (value 2) must be rejected. all hand-computed.
        let sut = QuizSessionViewModel(
            category: .decimalInt,
            stats: makeStats(),
            randomValue: { Decimal(5) },
            pickDirection: pin(10, 2)
        )
        #expect(sut.question.expectedAnswer == "101")
        sut.answer = "10"
        sut.check()
        #expect(sut.feedback != .correct)
        #expect(sut.feedback == .wrong(correctAnswer: "101"))
    }

    // MARK: Statistics integration

    @Test(arguments: ["", " ", "\n", "-", ".", ",", "-."])
    func incompleteAnswersCannotEarnCreditForZero(_ answer: String) {
        let stats = makeStats()
        let sut = QuizSessionViewModel(
            category: .binaryInt,
            stats: stats,
            randomValue: { .zero },
            pickDirection: pin(2, 10)
        )
        sut.answer = answer
        sut.check()

        #expect(sut.feedback == .wrong(correctAnswer: "0"))
        #expect(stats.allRight == 0)
    }

    @Test
    func explicitZeroWithSurroundingWhitespaceIsAccepted() {
        let sut = QuizSessionViewModel(
            category: .binaryInt,
            stats: makeStats(),
            randomValue: { .zero },
            pickDirection: pin(2, 10)
        )
        sut.answer = " \n0\n "
        sut.check()

        #expect(sut.feedback == .correct)
        sut.dismissFeedback()
        #expect(sut.feedback == nil)
        #expect(sut.statsAsked == 1)
        #expect(sut.statsRight == 1)
    }

    @Test
    func asksAreCountedOnGenerate() {
        let stats = makeStats()
        let sut = QuizSessionViewModel(category: .binaryInt, stats: stats)
        // one question generated in init.
        #expect(stats.asked(.binaryInt) == 1)
        #expect(stats.allAsked == 1)

        sut.nextQuestion()
        #expect(stats.asked(.binaryInt) == 2)
        #expect(stats.allAsked == 2)
    }

    @Test
    func rightIsCountedOncePerQuestion() {
        let stats = makeStats()
        let sut = QuizSessionViewModel(category: .binaryInt, stats: stats)
        sut.answer = sut.question.expectedAnswer

        sut.check()
        sut.check() // re-tap must not double-count.

        #expect(stats.right(.binaryInt) == 1)
        #expect(stats.allRight == 1)
    }

    @Test
    func wrongAnswerDoesNotCountRight() {
        let stats = makeStats()
        let sut = QuizSessionViewModel(category: .binaryInt, stats: stats)
        sut.answer = "#not-valid#"
        sut.check()

        #expect(stats.right(.binaryInt) == 0)
        #expect(stats.allRight == 0)
    }

    @Test
    func nextQuestionClearsAnswerAndFeedback() {
        let sut = QuizSessionViewModel(category: .binaryInt, stats: makeStats())
        sut.answer = sut.question.expectedAnswer
        sut.check()
        #expect(sut.feedback != nil)

        sut.nextQuestion()
        #expect(sut.answer.isEmpty)
        #expect(sut.feedback == nil)
    }

    // MARK: Helpers

    /// number of digits after the radix point in a rendered number.
    private func fractionDigitCount(_ rendered: String) -> Int {
        guard let dot = rendered.firstIndex(of: ".") else { return 0 }
        return rendered.distance(from: rendered.index(after: dot), to: rendered.endIndex)
    }
}
