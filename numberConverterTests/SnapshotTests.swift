//
//  SnapshotTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
@testable import numberConverter
import SnapshotTesting
import SwiftUI
import XCTest

// MARK: - SnapshotTests

/// image-snapshot matrix for every main screen across locale × appearance ×
/// device, plus the important converter states and a large Dynamic Type pass.
@MainActor
final class SnapshotTests: XCTestCase {
    // MARK: Core screens (locale × appearance × device)

    func test_tabBar() {
        forEachMatrixCell { cell in
            assertScreen(
                RootView(tipStore: TipStore(service: SnapshotTipService(locale: cell.locale))),
                named: "tab-bar",
                cell: cell,
                embedsInNavigationStack: false
            )
        }
    }

    func test_support() async {
        for locale in SnapshotLocale.allCases {
            let store = TipStore(service: SnapshotTipService(locale: locale))
            await store.loadProducts()
            for appearance in SnapshotAppearance.allCases {
                for device in SnapshotDevice.allCases {
                    autoreleasepool {
                        assertScreen(
                            SupportView(store: store),
                            named: "support",
                            cell: MatrixCell(locale: locale, appearance: appearance, device: device)
                        )
                    }
                }
            }
        }
    }

    func test_supportStatesAtLargestText() async {
        for locale in SnapshotLocale.allCases {
            for mode in ["available", "unavailable", "pending", "purchased", "unverified", "failed"] {
                let store = TipStore(service: SnapshotTipService(locale: locale, mode: mode))
                await store.loadProducts()
                if mode != "available", let product = store.products.first {
                    await store.purchase(product)
                }
                autoreleasepool {
                    assertScreen(
                        SupportView(store: store),
                        named: "support-\(mode)-ax5",
                        cell: MatrixCell(locale: locale, appearance: .light, device: .compact),
                        dynamicTypeSize: .accessibility5
                    )
                }
            }
        }
    }

    func test_converter() {
        forEachMatrixCell { cell in
            assertScreen(ConverterView(), named: "converter", cell: cell)
        }
    }

    func test_mainSystems() {
        forEachMatrixCell { cell in
            assertScreen(MainSystemsView(base: 10, number: "255"), named: "main-systems", cell: cell)
        }
    }

    func test_decimalToAll() {
        forEachMatrixCell { cell in
            assertScreen(DecimalToAllView(number: "255"), named: "decimal-to-all", cell: cell)
        }
    }

    func test_allSystems() {
        forEachMatrixCell { cell in
            assertScreen(AllSystemsView(), named: "all-systems", cell: cell)
        }
    }

    func test_calculator() {
        forEachMatrixCell { cell in
            assertScreen(CalculatorView(), named: "calculator", cell: cell)
        }
    }

    func test_quizMenu() {
        forEachMatrixCell { cell in
            assertScreen(QuizMenuView(), named: "quiz-menu", cell: cell, embedsInNavigationStack: false)
        }
    }

    func test_quizSession() {
        forEachMatrixCell { cell in
            assertScreen(makeSeededSession(), named: "quiz-session", cell: cell)
        }
    }

    func test_quizStats() {
        forEachMatrixCell { cell in
            assertScreen(QuizStatsView(viewModel: makeSeededStats()), named: "quiz-stats", cell: cell)
        }
    }

    func test_helpIndex() {
        forEachMatrixCell { cell in
            assertScreen(HelpIndexView(), named: "help-index", cell: cell, embedsInNavigationStack: false)
        }
    }

    func test_privacy() {
        forEachMatrixCell { cell in
            assertScreen(PrivacyView(), named: "privacy", cell: cell)
        }
    }

    func test_helpPage2() {
        forEachMatrixCell { cell in
            assertScreen(HelpPageView(topic: HelpContent.topic(page: 2)), named: "help-page2", cell: cell)
        }
    }

    func test_helpPages() {
        for page in [1, 3, 4, 5, 6, 7, 8, 9] {
            forEachMatrixCell { cell in
                assertScreen(HelpPageView(topic: HelpContent.topic(page: page)), named: "help-page-\(page)", cell: cell)
            }
        }
    }

    func test_resultErrors() {
        let errors: [ConversionError] = [.invalidCharacter, .baseOutOfRange, .divisionByZero, .numberOutOfRange]
        for (index, error) in errors.enumerated() {
            for locale in SnapshotLocale.allCases {
                assertScreen(
                    Form {
                        ResultRow(
                            label: "allSystems.field.result",
                            prompt: "",
                            result: "",
                            error: error,
                            accessibilityPrefix: "result"
                        )
                    },
                    named: "result-error-\(index)",
                    cell: MatrixCell(locale: locale, appearance: .light, device: .compact)
                )
            }
        }
    }

    func test_longResults() {
        for locale in SnapshotLocale.allCases {
            for size in [DynamicTypeSize.large, .accessibility5] {
                assertScreen(
                    Form {
                        ResultRow(
                            label: "allSystems.field.result",
                            prompt: "",
                            result: "12345678901234567890123456789012345678",
                            error: nil,
                            accessibilityPrefix: "result"
                        )
                    },
                    named: "long-result-\(size)",
                    cell: MatrixCell(locale: locale, appearance: .light, device: .compact),
                    dynamicTypeSize: size
                )
            }
        }
    }

    // MARK: Converter states (iPhone × ru × {light, dark})

    func test_converterStates() {
        for appearance in SnapshotAppearance.allCases {
            let cell = MatrixCell(locale: .ru, appearance: appearance, device: .iphone)
            assertScreen(state(makeConverter()), named: "converter-state-empty", cell: cell)
            assertScreen(state(makeConverter(decimal: "255")), named: "converter-state-filled", cell: cell)
            assertScreen(state(makeInvalidConverter()), named: "converter-state-invalid", cell: cell)
            assertScreen(
                state(makeConverter(decimal: "-1", twosComplement: true)),
                named: "converter-state-twos-complement",
                cell: cell,
                twosComplement: true
            )
        }
    }

    // MARK: Large Dynamic Type (iPhone × ru × {light, dark})

    func test_converterLargeDynamicType() {
        for locale in SnapshotLocale.allCases {
            for appearance in SnapshotAppearance.allCases {
                for device in [SnapshotDevice.compact, .iphone] {
                    assertScreen(
                        state(makeConverter(decimal: "255")),
                        named: "converter-dynamic-type-ax5",
                        cell: MatrixCell(locale: locale, appearance: appearance, device: device),
                        dynamicTypeSize: .accessibility5
                    )
                }
            }
        }
    }

    // MARK: Fixtures

    /// the real converter screen seeded with a view model in a known state.
    private func state(_ viewModel: ConverterViewModel) -> ConverterView {
        ConverterView(viewModel: viewModel)
    }

    /// a converter view model seeded by replaying a user edit, so every field is
    /// filled exactly as the live screen would fill them.
    private func makeConverter(decimal: String = "", twosComplement: Bool = false) -> ConverterViewModel {
        let viewModel = ConverterViewModel(twosComplement: twosComplement)
        if !decimal.isEmpty {
            viewModel.userEdited(.decimal, decimal)
        }
        return viewModel
    }

    /// a converter view model in an invalid state: a bad binary digit flags the
    /// binary field while the other fields keep their valid values.
    private func makeInvalidConverter() -> ConverterViewModel {
        let viewModel = ConverterViewModel()
        viewModel.userEdited(.decimal, "255")
        viewModel.userEdited(.binary, "1012") // 2 is not a binary digit
        return viewModel
    }

    /// the real quiz-session screen with a view model pinned to a fixed value
    /// (255) and direction (10→2), so both number and direction are stable.
    private func makeSeededSession() -> QuizSessionView {
        let viewModel = QuizSessionViewModel(
            category: .binaryInt,
            stats: QuizStats(defaults: isolatedDefaults()),
            randomValue: { Decimal(255) },
            pickDirection: { _ in QuizDirection(source: 10, target: 2) }
        )
        return QuizSessionView(category: .binaryInt, viewModel: viewModel)
    }

    /// a stats view model backed by an isolated suite pre-seeded with a known
    /// set of counters, so the rendered numbers are stable across runs.
    private func makeSeededStats() -> QuizStatsViewModel {
        let stats = QuizStats(defaults: isolatedDefaults())
        seed(stats, category: .binaryInt, asked: 12, right: 9)
        seed(stats, category: .octalInt, asked: 8, right: 5)
        seed(stats, category: .decimalInt, asked: 20, right: 17)
        seed(stats, category: .hexInt, asked: 6, right: 6)
        seed(stats, category: .binaryFraction, asked: 4, right: 1)
        return QuizStatsViewModel(stats: stats)
    }

    /// records `asked` questions and `right` correct answers for `category`.
    private func seed(_ stats: QuizStats, category: QuizCategory, asked: Int, right: Int) {
        for _ in 0 ..< asked {
            stats.recordAsked(category)
        }
        for _ in 0 ..< right {
            stats.recordRight(category)
        }
    }
}
