//
//  QuizMenuView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - QuizDestination

/// the screens pushed from the quiz menu: a session for a quiz, or the stats.
enum QuizDestination: Hashable {
    case session(QuizCategory)
    case statistics
}

// MARK: - QuizMenuView

/// root screen of the quiz tab: the eight quizzes plus the overall-statistics row.
struct QuizMenuView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedDestination: QuizDestination?
    @State private var lastSelectedDestination: QuizDestination?
    @State private var activeSession: QuizSessionViewModel?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            quizList
                .navigationTitle(Text(AppTab.quiz.navigationTitleKey))
                .appHelpToolbar(isEnabled: horizontalSizeClass != .regular)
                .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        } detail: {
            NavigationStack {
                detail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular, selectedDestination == nil {
                selectedDestination = lastSelectedDestination
            }
        }
        .onAppear { AppLogger.quiz.screen("quizMenu") }
    }

    private var quizList: some View {
        List(selection: selection) {
            Section {
                ForEach(QuizCategory.allCases) { category in
                    NavigationLink(value: QuizDestination.session(category)) {
                        Text(category.menuRowKey)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("quiz.category.\(category.rawValue)")
                }
                NavigationLink(value: QuizDestination.statistics) {
                    Text("quiz.menu.row9")
                        .accessibilityIdentifier("quiz.statisticsLabel")
                }
                .accessibilityIdentifier("quiz.statistics")
            } header: {
                Text("quiz.menu.sectionHeader")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("quiz.sidebar")
    }

    @ViewBuilder private var detail: some View {
        switch selectedDestination {
        case let .session(category):
            if let activeSession {
                QuizSessionView(category: category, viewModel: activeSession, onFinish: finishSession)
                    .id(category)
            }
        case .statistics:
            QuizStatsView()
        case .none:
            ContentUnavailableView {
                Label("nav.quiz", systemImage: "checklist")
            } description: {
                Text("quiz.menu.sectionHeader")
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .navigationTitle(Text(AppTab.quiz.navigationTitleKey))
            .appHelpToolbar()
        }
    }

    private var selection: Binding<QuizDestination?> {
        Binding(
            get: { selectedDestination },
            set: { destination in
                if destination == .statistics {
                    activeSession = nil
                }
                if case let .session(category) = destination, activeSession?.category != category {
                    activeSession = QuizSessionViewModel(category: category)
                }
                selectedDestination = destination
                if let destination {
                    lastSelectedDestination = destination
                    preferredCompactColumn = .detail
                }
            }
        )
    }

    private func finishSession() {
        activeSession = nil
        selectedDestination = nil
        lastSelectedDestination = nil
        preferredCompactColumn = .sidebar
        columnVisibility = .all
    }
}

#Preview {
    QuizMenuView()
        .environment(\.locale, Locale(identifier: "ru"))
}
