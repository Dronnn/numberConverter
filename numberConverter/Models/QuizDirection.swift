//
//  QuizDirection.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

// MARK: - QuizDirection

/// a single conversion direction in a quiz question: render a value in the
/// `source` base and ask the user to convert it to the `target` base. each
/// distinct base pair maps to one verbatim russian prompt.
struct QuizDirection: Hashable {
    let source: Int
    let target: Int

    /// localization key for the prompt. returns a static literal per base pair
    /// so the string catalog lookup hits the concrete key; interpolating the
    /// bases would collapse it to a `%lld-%lld` format template with no value.
    var promptKey: LocalizedStringResource {
        switch (source, target) {
        case (2, 10): "quiz.prompt.2-10"
        case (10, 2): "quiz.prompt.10-2"
        case (8, 2): "quiz.prompt.8-2"
        case (2, 8): "quiz.prompt.2-8"
        case (16, 2): "quiz.prompt.16-2"
        case (2, 16): "quiz.prompt.2-16"
        case (8, 10): "quiz.prompt.8-10"
        case (10, 8): "quiz.prompt.10-8"
        case (16, 8): "quiz.prompt.16-8"
        case (8, 16): "quiz.prompt.8-16"
        case (16, 10): "quiz.prompt.16-10"
        case (10, 16): "quiz.prompt.10-16"
        default: "quiz.prompt.2-10"
        }
    }
}
