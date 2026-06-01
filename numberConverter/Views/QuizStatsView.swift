//
//  QuizStatsView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - QuizStatsView

/// the overall statistics screen (menu row 9): the aggregate counters, a
/// per-quiz breakdown, and a destructive reset.
struct QuizStatsView: View {
    @State private var viewModel = QuizStatsViewModel()
    @State private var isConfirmingReset = false

    var body: some View {
        List {
            Section {
                QuizStatsRowView(row: viewModel.overall)
            } header: {
                Text("quiz.stats.overall")
            }

            Section {
                ForEach(viewModel.rows) { row in
                    QuizStatsRowView(row: row)
                }
            } header: {
                Text("quiz.stats.perQuiz")
            }

            Section {
                Button("quiz.stats.reset", role: .destructive) {
                    isConfirmingReset = true
                }
            }
        }
        .navigationTitle(Text("quiz.menu.row9"))
        .alert("quiz.stats.resetConfirmTitle", isPresented: $isConfirmingReset) {
            Button("quiz.stats.reset", role: .destructive) {
                viewModel.reset()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("quiz.stats.resetConfirmMessage")
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
            Text(QuizStatsText.message(asked: row.asked, right: row.right))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        QuizStatsView()
    }
    .environment(\.locale, Locale(identifier: "ru"))
}
