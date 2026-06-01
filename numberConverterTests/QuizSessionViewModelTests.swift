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
struct QuizSessionViewModelTests {
    /// an isolated stats store backed by an empty UserDefaults suite.
    private func makeStats() -> QuizStats {
        let suiteName = "quiz.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return QuizStats(defaults: defaults)
    }

    private static let fractionCategories: [QuizCategory] =
        [.binaryFraction, .octalFraction, .decimalFraction, .hexFraction]

    private static let integerCategories: [QuizCategory] =
        [.binaryInt, .octalInt, .decimalInt, .hexInt]

    // MARK: Direction & answer correctness (the legacy-bug fix)

    /// for every direction of every quiz, the displayed number and the expected
    /// answer are the same value rendered in the two bases, both finite and
    /// (for fractions) ≤ six fraction digits. proved by generating many
    /// questions so all six directions are exercised.
    @Test
    func fractionAnswersAreFiniteAndCorrectAcrossDirections() {
        for category in Self.fractionCategories {
            var seenDirections: Set<QuizDirection> = []
            for _ in 0 ..< 400 {
                let sut = QuizSessionViewModel(category: category, stats: makeStats())
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
        for category in Self.integerCategories {
            var seenDirections: Set<QuizDirection> = []
            for _ in 0 ..< 400 {
                let sut = QuizSessionViewModel(category: category, stats: makeStats())
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
        // value 10/16 = 0.A in hex; keep drawing until the target base is 16,
        // then assert a lowercase form is accepted.
        var sut = QuizSessionViewModel(category: .hexFraction, stats: makeStats()) {
            Decimal(10) / Decimal(16)
        }
        var attempts = 0
        while sut.question.direction.target != 16, attempts < 200 {
            sut = QuizSessionViewModel(category: .hexFraction, stats: makeStats()) {
                Decimal(10) / Decimal(16)
            }
            attempts += 1
        }
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
        let sut = QuizSessionViewModel(category: .decimalInt, stats: makeStats()) {
            Decimal(5)
        }
        // pick any target; the value is 5, so a wrong numeric answer in the
        // target base must be rejected. use a value-2 string in that base.
        let wrong = ConversionEngine.fromDecimal(Decimal(2), toBase: sut.question.direction.target) ?? "2"
        sut.answer = wrong
        sut.check()
        #expect(sut.feedback != .correct)
    }

    // MARK: Statistics integration

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
