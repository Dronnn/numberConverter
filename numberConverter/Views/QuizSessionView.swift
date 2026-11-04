//
//  QuizSessionView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - QuizSessionView

/// one quiz session: shows the current question, takes the user's answer,
/// checks it, and reports per-quiz statistics. «Закончить» pops back to the menu.
struct QuizSessionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: QuizSessionViewModel
    @State private var isShowingStats = false

    private let onFinish: (() -> Void)?

    init(category: QuizCategory, viewModel: QuizSessionViewModel? = nil, onFinish: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel ?? QuizSessionViewModel(category: category))
        self.onFinish = onFinish
    }

    var body: some View {
        Form {
            Section {
                Text(viewModel.category.headerKey)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("quiz.header")
            }

            QuizQuestionSection(viewModel: viewModel)

            QuizAnswerSection(viewModel: viewModel) {
                isShowingStats = true
            }
        }
        .accessibilityIdentifier("quiz.session")
        .navigationTitle(Text("quiz.session.title"))
        .appHelpToolbar()
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDismissal()
        .onAppear { AppLogger.quiz.screen("quizSession") }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("quiz.session.finish") {
                    if let onFinish {
                        onFinish()
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("quiz.finish")
            }
        }
        .alert("quiz.session.feedbackTitle", isPresented: feedbackBinding) {
            Button("common.ok", role: .cancel) { viewModel.dismissFeedback() }
        } message: {
            QuizFeedbackMessage(feedback: viewModel.feedback)
        }
        .alert("quiz.stats.title", isPresented: $isShowingStats) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(QuizStatsText.message(asked: viewModel.statsAsked, right: viewModel.statsRight))
        }
    }

    /// drives the feedback alert from the view model's optional feedback.
    private var feedbackBinding: Binding<Bool> {
        Binding(
            get: { viewModel.feedback != nil },
            set: {
                if !$0 {
                    viewModel.dismissFeedback()
                }
            }
        )
    }
}

// MARK: - QuizQuestionSection

/// shows the «Вопрос:» label, the direction prompt, the number to convert, and
/// the «Ещё вопрос» button.
private struct QuizQuestionSection: View {
    let viewModel: QuizSessionViewModel

    var body: some View {
        Section {
            Text("quiz.session.questionLabel")
            Text(viewModel.question.direction.promptKey)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("quiz.prompt")
            Text(verbatim: viewModel.question.displayed)
                .bold()
                .textSelection(.enabled)
                .accessibilityIdentifier("quiz.question")
            Button("quiz.session.nextQuestion") {
                viewModel.nextQuestion()
            }
            .accessibilityIdentifier("quiz.next")
        }
    }
}

// MARK: - QuizAnswerSection

/// shows the «Ответ:» label, the answer field, and the check / statistics buttons.
private struct QuizAnswerSection: View {
    @Bindable var viewModel: QuizSessionViewModel
    let onShowStats: () -> Void

    var body: some View {
        Section {
            Text("quiz.session.answerLabel")
            TextField(text: $viewModel.answer, axis: .vertical) {
                Text("quiz.session.answerPlaceholder")
            }
            .lineLimit(nil)
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("quiz.answer")
            Button("quiz.session.check") {
                viewModel.check()
            }
            .accessibilityIdentifier("quiz.check")
            Button("quiz.stats.title", action: onShowStats)
                .accessibilityIdentifier("quiz.statistics")
        }
    }
}

// MARK: - QuizFeedbackMessage

/// the feedback-alert message: a verdict, plus the correct answer on a miss.
private struct QuizFeedbackMessage: View {
    let feedback: QuizFeedback?

    var body: some View {
        switch feedback {
        case .correct:
            Text("quiz.session.correct")
        case let .wrong(correctAnswer):
            Text("quiz.session.wrong")
                + Text(verbatim: "\n")
                + Text("quiz.session.correctAnswerIs \(correctAnswer)")
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        QuizSessionView(category: .binaryFraction)
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
