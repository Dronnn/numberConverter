//
//  QuizStatsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - QuizStatsView

/// the overall statistics screen (menu row 9): the aggregate counters, a
/// per-quiz breakdown, and a destructive reset.
struct QuizStatsView: View {
    @State private var viewModel: QuizStatsViewModel
    @State private var isConfirmingReset = false

    init(viewModel: QuizStatsViewModel = QuizStatsViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                QuizStatsRowView(row: viewModel.overall)
            } header: {
                Text("quiz.stats.overall")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(viewModel.rows) { row in
                    QuizStatsRowView(row: row)
                }
            } header: {
                Text("quiz.stats.perQuiz")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button("quiz.stats.reset", role: .destructive) {
                    isConfirmingReset = true
                }
                .accessibilityIdentifier("statistics.reset")
            }
        }
        .modifier(StatisticsScrollEdgeEffect())
        .navigationTitle(Text("quiz.stats.title"))
        .appHelpToolbar()
        .accessibilityIdentifier("statistics.list")
        .onAppear { AppLogger.quiz.screen("quizStats") }
        .alert("quiz.stats.resetConfirmTitle", isPresented: $isConfirmingReset) {
            Button("quiz.stats.reset", role: .destructive) {
                viewModel.reset()
            }
            .accessibilityIdentifier("statistics.resetConfirm")
            Button("common.cancel", role: .cancel) {}
                .accessibilityIdentifier("statistics.cancel")
        } message: {
            Text("quiz.stats.resetConfirmMessage")
        }
    }
}

private struct StatisticsScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectStyle(.hard, for: .bottom)
        } else {
            content
        }
    }
}

// MARK: - QuizStatsRowView

/// a labeled statistics row: the quiz title and its «Всего вопросов / правильно» line.
private struct QuizStatsRowView: View {
    let row: QuizStatsRow

    var body: some View {
        VStack(alignment: .leading) {
            Text(row.titleKey)
                .fixedSize(horizontal: false, vertical: true)
            Text(QuizStatsText.message(asked: row.asked, right: row.right))
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("statistics.counts.\(row.id)")
        }
    }
}

#Preview {
    NavigationStack {
        QuizStatsView()
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
