//
//  ApplicationStateTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import Observation
import Testing

@MainActor
final class ApplicationStateTests {
    private var suiteNames: [String] = []

    deinit {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "app-state.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        suiteNames.append(name)
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test
    func settingsPersistUnderTheExistingKeyAcrossInstances() throws {
        let defaults = try makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.twosComplement)

        settings.twosComplement = true
        #expect(defaults.bool(forKey: "twosComplement"))
        #expect(AppSettings(defaults: defaults).twosComplement)

        settings.twosComplement = false
        #expect(!AppSettings(defaults: defaults).twosComplement)
    }

    @Test
    func settingsChangesInvalidateObservation() async throws {
        let settings = try AppSettings(defaults: makeDefaults())
        await confirmation("the shared setting changes", expectedCount: 1) { changed in
            withObservationTracking {
                _ = settings.twosComplement
            } onChange: {
                changed()
            }
            settings.twosComplement = true
        }
    }

    @Test
    func navigationSelectsEveryTabByItsStableIdentifier() {
        let navigation = AppNavigationState(selectedTab: .info)
        #expect(navigation.selectedTab == .converter)
        #expect(navigation.isShowingHelp)

        for tab in AppTab.tabs {
            navigation.select(tabID: tab.rawValue)
            #expect(navigation.selectedTab == tab)
            #expect(!navigation.isShowingHelp)
        }

        navigation.select(tabID: "info")
        #expect(navigation.selectedTab == .support)
        #expect(navigation.isShowingHelp)
        navigation.select(tabID: "unrecognized-tab")
        #expect(navigation.selectedTab == .support)
        #expect(navigation.isShowingHelp)
    }

    @Test
    func helpPresentationPreservesTheCurrentToolAndToolNavigationClosesIt() {
        let navigation = AppNavigationState(selectedTab: .calculator)
        navigation.presentHelp()
        #expect(navigation.selectedTab == .calculator)
        #expect(navigation.isShowingHelp)

        navigation.select(tabID: "support")
        #expect(navigation.selectedTab == .support)
        #expect(!navigation.isShowingHelp)
        #expect(AppTab.tabs == [.converter, .allSystems, .calculator, .quiz, .support])
        #expect(AppTab.toolTabs == [.converter, .allSystems, .calculator, .quiz])
        #expect(!AppTab.tabs.contains(.info))
    }

    @Test
    func categoriesHaveDistinctKeysAndCompleteDirectionSets() {
        let bases = [2, 8, 10, 16, 2, 8, 10, 16]
        let headers = [
            "binaryInt", "octalInt", "decimalInt", "hexInt",
            "binaryFraction", "octalFraction", "decimalFraction", "hexFraction"
        ]
        for (index, category) in QuizCategory.allCases.enumerated() {
            #expect(category.id == category.rawValue)
            #expect(category.isFraction == (index >= 4))
            #expect(category.menuRowKey.key == "quiz.menu.row\(index + 1)")
            #expect(category.headerKey.key == "quiz.session.header.\(headers[index])")
            #expect(category.directions.count == 6)
            #expect(Set(category.directions).count == 6)
            for direction in category.directions {
                #expect(direction.source != direction.target)
                #expect(direction.source == bases[index] || direction.target == bases[index])
                #expect(direction.promptKey.key == "quiz.prompt.\(direction.source)-\(direction.target)")
            }
        }
        #expect(Set(QuizCategory.allCases.map(\.askedKey)).count == 8)
        #expect(Set(QuizCategory.allCases.map(\.rightKey)).count == 8)
    }

    @Test
    func unsupportedQuizDirectionUsesTheDocumentedFallbackPrompt() {
        #expect(QuizDirection(source: 3, target: 7).promptKey.key == "quiz.prompt.2-10")
    }

    @Test
    func persistedStatisticsSurviveStoreRecreationAndReset() throws {
        let defaults = try makeDefaults()
        let first = QuizStats(defaults: defaults)
        first.recordAsked(.hexFraction)
        first.recordRight(.hexFraction)

        let reloaded = QuizStats(defaults: defaults)
        #expect(reloaded.asked(.hexFraction) == 1)
        #expect(reloaded.right(.hexFraction) == 1)
        #expect(reloaded.allAsked == 1)
        #expect(reloaded.allRight == 1)

        reloaded.reset()
        #expect(first.asked(.hexFraction) == 0)
        #expect(first.right(.hexFraction) == 0)
    }

    @Test
    func quizSessionResultsAppearInStatisticsAndResetTogether() throws {
        let stats = try QuizStats(defaults: makeDefaults())
        let statistics = QuizStatsViewModel(stats: stats)
        let session = QuizSessionViewModel(
            category: .binaryInt,
            stats: stats,
            randomValue: { Decimal(5) },
            pickDirection: { _ in QuizDirection(source: 2, target: 10) }
        )
        #expect(session.question.displayed == "101")
        #expect(session.statsAsked == 1)
        session.answer = "5"
        session.check()
        #expect(session.feedback == .correct)
        #expect(session.statsRight == 1)
        #expect(statistics.overall.id == "all")
        #expect(statistics.overall.titleKey.key == "quiz.stats.overall")
        #expect(statistics.overall.asked == 1)
        #expect(statistics.overall.right == 1)

        let rows = statistics.rows
        #expect(rows.map(\.id) == QuizCategory.allCases.map(\.rawValue))
        #expect(rows.first?.asked == 1)
        #expect(rows.first?.right == 1)
        #expect(rows.first?.titleKey.key == "quiz.menu.row1")
        #expect(rows.dropFirst().allSatisfy { $0.asked == 0 && $0.right == 0 })

        let previousVersion = statistics.version
        statistics.reset()
        #expect(statistics.version == previousVersion + 1)
        #expect(statistics.overall.asked == 0)
        #expect(statistics.overall.right == 0)
        #expect(statistics.rows.allSatisfy { $0.asked == 0 && $0.right == 0 })
    }

    @Test
    func persistedSignedModeAndEveryNavigationSeedPreserveBoundaryValues() throws {
        let defaults = try makeDefaults()
        AppSettings(defaults: defaults).twosComplement = true
        let settings = AppSettings(defaults: defaults)
        let converter = ConverterViewModel(twosComplement: settings.twosComplement)

        for value in [Int.min, -129, -128, -1, 0, 1, 127, 128, 255, Int.max] {
            converter.userEdited(.decimal, String(value))
            #expect(converter.invalidFields.isEmpty)
            for field in BaseField.allCases {
                let seed = converter.seed(for: field)
                let detail = MainSystemsViewModel(
                    base: seed.base,
                    number: seed.number,
                    twosComplement: settings.twosComplement
                )
                #expect(detail.decimal == String(value))
                #expect(detail.binary == converter.binary)
                #expect(detail.octal == converter.octal)
                #expect(detail.hexadecimal == converter.hexadecimal)
            }
        }
    }
}
