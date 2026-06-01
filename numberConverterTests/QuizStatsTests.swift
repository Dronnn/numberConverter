//
//  QuizStatsTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import Testing

// MARK: - QuizStatsTests

@MainActor
final class QuizStatsTests {
    /// suite names created by this test instance, torn down in `deinit`.
    private var suiteNames: [String] = []

    deinit {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    /// an isolated, empty UserDefaults suite so tests never touch real defaults.
    /// the suite is always isolated; we never fall back to `.standard`.
    private func makeStats() -> (QuizStats, UserDefaults) {
        let suiteName = "quiz.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("could not create isolated UserDefaults suite \(suiteName)")
        }
        suiteNames.append(suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        return (QuizStats(defaults: defaults), defaults)
    }

    @Test
    func startsAtZero() {
        let (stats, _) = makeStats()
        #expect(stats.asked(.binaryInt) == 0)
        #expect(stats.right(.binaryInt) == 0)
        #expect(stats.allAsked == 0)
        #expect(stats.allRight == 0)
    }

    @Test
    func recordAskedBumpsQuizAndAggregate() {
        let (stats, _) = makeStats()
        stats.recordAsked(.octalFraction)
        stats.recordAsked(.octalFraction)

        #expect(stats.asked(.octalFraction) == 2)
        #expect(stats.allAsked == 2)
        // a different quiz is untouched.
        #expect(stats.asked(.binaryInt) == 0)
    }

    @Test
    func recordRightBumpsQuizAndAggregate() {
        let (stats, _) = makeStats()
        stats.recordRight(.hexInt)

        #expect(stats.right(.hexInt) == 1)
        #expect(stats.allRight == 1)
    }

    @Test
    func resetZeroesAllEighteenKeys() {
        let (stats, defaults) = makeStats()
        for category in QuizCategory.allCases {
            stats.recordAsked(category)
            stats.recordRight(category)
        }

        stats.reset()

        for category in QuizCategory.allCases {
            #expect(defaults.integer(forKey: category.askedKey) == 0)
            #expect(defaults.integer(forKey: category.rightKey) == 0)
        }
        #expect(defaults.integer(forKey: QuizStats.allAskedKey) == 0)
        #expect(defaults.integer(forKey: QuizStats.allRightKey) == 0)
    }

    @Test
    func legacyKeysAreVerbatim() {
        #expect(QuizCategory.binaryInt.askedKey == "binQuestionCount")
        #expect(QuizCategory.binaryInt.rightKey == "binQuestionRightCount")
        #expect(QuizCategory.octalInt.askedKey == "octQuestionCount")
        #expect(QuizCategory.decimalInt.askedKey == "decQuestionCount")
        #expect(QuizCategory.hexInt.askedKey == "hexQuestionCount")
        #expect(QuizCategory.binaryFraction.askedKey == "binFrQuestionCount")
        #expect(QuizCategory.octalFraction.rightKey == "octFrQuestionRightCount")
        #expect(QuizCategory.decimalFraction.askedKey == "decFrQuestionCount")
        #expect(QuizCategory.hexFraction.rightKey == "hexFrQuestionRightCount")
        #expect(QuizStats.allAskedKey == "allQuestionCount")
        #expect(QuizStats.allRightKey == "allQuestionRightCount")
    }
}
