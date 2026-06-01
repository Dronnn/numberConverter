//
//  QuizSessionView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - QuizSessionView

/// one quiz session: shows the current question, takes the user's answer,
/// checks it, and reports per-quiz statistics. «Закончить» pops back to the menu.
struct QuizSessionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: QuizSessionViewModel
    @State private var isShowingStats = false

    init(category: QuizCategory) {
        _viewModel = State(initialValue: QuizSessionViewModel(category: category))
    }

    var body: some View {
        Form {
            Section {
                Text(viewModel.category.headerKey)
            }

            QuizQuestionSection(viewModel: viewModel)

            QuizAnswerSection(viewModel: viewModel) {
                isShowingStats = true
            }
        }
        .navigationTitle(Text("quiz.session.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("quiz.session.finish") { dismiss() }
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
            set: { if !$0 { viewModel.dismissFeedback() } }
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
            Text(verbatim: viewModel.question.displayed)
                .bold()
                .textSelection(.enabled)
            Button("quiz.session.nextQuestion") {
                viewModel.nextQuestion()
            }
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
            TextField(text: $viewModel.answer) {
                Text("quiz.session.answerPlaceholder")
            }
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            Button("quiz.session.check") {
                viewModel.check()
            }
            Button("quiz.stats.title", action: onShowStats)
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
