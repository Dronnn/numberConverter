//
//  QuizQuestion.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - QuizQuestion

/// one generated quiz question. the `displayed` string is the value rendered in
/// the direction's source base; the `expectedAnswer` is the same value rendered
/// in the target base (the engine's canonical form). `expectedValue` is the
/// exact decimal value, used to check answers by value rather than by string.
struct QuizQuestion: Equatable {
    let direction: QuizDirection
    let displayed: String
    let expectedAnswer: String
    let expectedValue: Decimal
}
