//
//  QuizCategory.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - QuizCategory

/// the eight quizzes (four numeral systems × {integer, fraction}). each quiz
/// has its own pair of legacy UserDefaults counters and a fixed set of six
/// conversion directions; the `all` aggregate is updated alongside every quiz.
enum QuizCategory: String, CaseIterable, Identifiable, Hashable {
    case binaryInt
    case octalInt
    case decimalInt
    case hexInt
    case binaryFraction
    case octalFraction
    case decimalFraction
    case hexFraction

    var id: String {
        rawValue
    }

    // MARK: Persistence keys (verbatim legacy keys — do not rename)

    /// legacy UserDefaults key for this quiz's *asked* counter.
    var askedKey: String {
        switch self {
        case .binaryInt: "binQuestionCount"
        case .octalInt: "octQuestionCount"
        case .decimalInt: "decQuestionCount"
        case .hexInt: "hexQuestionCount"
        case .binaryFraction: "binFrQuestionCount"
        case .octalFraction: "octFrQuestionCount"
        case .decimalFraction: "decFrQuestionCount"
        case .hexFraction: "hexFrQuestionCount"
        }
    }

    /// legacy UserDefaults key for this quiz's *right* counter.
    var rightKey: String {
        switch self {
        case .binaryInt: "binQuestionRightCount"
        case .octalInt: "octQuestionRightCount"
        case .decimalInt: "decQuestionRightCount"
        case .hexInt: "hexQuestionRightCount"
        case .binaryFraction: "binFrQuestionRightCount"
        case .octalFraction: "octFrQuestionRightCount"
        case .decimalFraction: "decFrQuestionRightCount"
        case .hexFraction: "hexFrQuestionRightCount"
        }
    }

    // MARK: Shape

    /// whether this quiz asks fractional values (≤ six clean fraction digits).
    var isFraction: Bool {
        switch self {
        case .binaryFraction, .octalFraction, .decimalFraction, .hexFraction: true
        default: false
        }
    }

    // MARK: Localization keys

    /// the menu row title key. returns a static literal per case so the string
    /// catalog lookup hits the concrete key (interpolation would collapse it to
    /// a `%lld` format template that has no value).
    var menuRowKey: LocalizedStringResource {
        switch self {
        case .binaryInt: "quiz.menu.row1"
        case .octalInt: "quiz.menu.row2"
        case .decimalInt: "quiz.menu.row3"
        case .hexInt: "quiz.menu.row4"
        case .binaryFraction: "quiz.menu.row5"
        case .octalFraction: "quiz.menu.row6"
        case .decimalFraction: "quiz.menu.row7"
        case .hexFraction: "quiz.menu.row8"
        }
    }

    /// the session header key, one static literal per case (no interpolation).
    var headerKey: LocalizedStringResource {
        switch self {
        case .binaryInt: "quiz.session.header.binaryInt"
        case .octalInt: "quiz.session.header.octalInt"
        case .decimalInt: "quiz.session.header.decimalInt"
        case .hexInt: "quiz.session.header.hexInt"
        case .binaryFraction: "quiz.session.header.binaryFraction"
        case .octalFraction: "quiz.session.header.octalFraction"
        case .decimalFraction: "quiz.session.header.decimalFraction"
        case .hexFraction: "quiz.session.header.hexFraction"
        }
    }

    // MARK: Directions

    /// the six (source → target) directions this quiz picks from at random.
    /// the four numeral systems share the same direction set across their
    /// integer and fraction variants.
    var directions: [QuizDirection] {
        let pairs: [(Int, Int)] = switch self {
        case .binaryInt, .binaryFraction:
            [(2, 10), (10, 2), (8, 2), (2, 8), (16, 2), (2, 16)]
        case .octalInt, .octalFraction:
            [(8, 10), (10, 8), (8, 2), (2, 8), (16, 8), (8, 16)]
        case .decimalInt, .decimalFraction:
            [(2, 10), (10, 2), (8, 10), (10, 8), (16, 10), (10, 16)]
        case .hexInt, .hexFraction:
            [(16, 10), (10, 16), (16, 2), (2, 16), (16, 8), (8, 16)]
        }
        return pairs.map { QuizDirection(source: $0.0, target: $0.1) }
    }
}
