//
//  NativeTabSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    /// iPad's native tab strip pages at larger text sizes. validate all five
    /// identifiers and translated labels across pages, rather than assuming
    /// every native control is exposed simultaneously.
    func verifyNativeTabInventory(language: UITestLanguage? = nil) throws {
        let language = try language ?? currentLaunchLanguage()
        let expected = Dictionary(uniqueKeysWithValues: zip(
            Self.tabIdentifiers.map { "app.tab.\($0)" }, language.tabLabels
        ))
        var seen: [String: String] = [:]
        for forward in [true, false, true] {
            collectNativeTabs(into: &seen, expected: expected)
            if seen == expected {
                return
            }
            let pager = nativeTabPager(forward: forward, language: language)
            if pager.exists, pager.isHittable {
                pager.tap()
            }
        }
        collectNativeTabs(into: &seen, expected: expected)
        XCTAssertEqual(seen, expected, "Every one of the five localized native tabs must be reachable")
    }

    func nativeTabButton(at index: Int) throws -> XCUIElement {
        let target = element("app.tab.\(Self.tabIdentifiers[index])")
        let language = try currentLaunchLanguage()
        for forward in [true, false, true] {
            if target.exists, target.isHittable {
                return target
            }
            let pager = nativeTabPager(forward: forward, language: language)
            if pager.exists, pager.isHittable {
                pager.tap()
            }
        }
        guard target.exists, target.isHittable else {
            XCTFail("Native tab is not reachable: \(Self.tabIdentifiers[index])")
            throw UIAuditError.missingElement(Self.tabIdentifiers[index])
        }
        return target
    }

    func testRussianLargestTextNativeTabPaging() throws {
        launch(.russian, largeText: true)
        try expectTabLabels(.russian)
        let destinations = [
            "converter.input.10", "allSystems.number", "calculator.operandA", "quiz.sidebar", "support.explanation"
        ]
        for (index, identifier) in destinations.enumerated() {
            try selectTab(index)
            XCTAssertTrue(try require(identifier).exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "ru-AX-native-tab-paging-\(index)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.terminate()
    }

    private func collectNativeTabs(into seen: inout [String: String], expected: [String: String]) {
        let controls = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "app.tab."))
        let elements = controls.allElementsBoundByIndex
        if elements.isEmpty, app.tabBars.firstMatch.exists {
            let labels = app.tabBars.firstMatch.buttons.allElementsBoundByIndex.map(\.label)
            XCTAssertEqual(labels.count, expected.count, "Expected exactly five native tab controls")
            XCTAssertEqual(Set(labels), Set(expected.values), "Expected all five localized native tab labels")
            for (identifier, label) in expected where labels.contains(label) {
                seen[identifier] = label
            }
            return
        }
        for control in elements {
            XCTAssertEqual(control.label, expected[control.identifier], "Unexpected native tab or translation")
            seen[control.identifier] = control.label
        }
    }

    /// iOS occasionally omits TabContent identifiers on a cold, unpinned launch.
    /// a fallback is allowed only inside an actual native tab bar exposing the
    /// complete, uniquely labeled set of five localized controls.
    func fallbackNativeTabControl(identifier: String) -> XCUIElement? {
        guard
            let index = Self.tabIdentifiers.firstIndex(where: { identifier == "app.tab.\($0)" }),
            let language = try? currentLaunchLanguage()
        else { return nil }
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists else { return nil }
        let labels = tabBar.buttons.allElementsBoundByIndex.map(\.label)
        guard labels.count == language.tabLabels.count, Set(labels) == Set(language.tabLabels) else { return nil }
        let matches = tabBar.buttons.matching(NSPredicate(format: "label == %@", language.tabLabels[index]))
        return matches.count == 1 ? matches.firstMatch : nil
    }

    private func currentLaunchLanguage() throws -> UITestLanguage {
        let argument = app.launchArguments.first { $0.hasPrefix("(") && $0.hasSuffix(")") }
        return try XCTUnwrap(argument.flatMap { UITestLanguage(rawValue: String($0.dropFirst().dropLast())) })
    }

    private func nativeTabPager(forward: Bool, language: UITestLanguage) -> XCUIElement {
        let names = switch language {
        case .english: ("Next page", "Previous page")
        case .russian: ("Следующая страница", "Предыдущая страница")
        case .spanish: ("Página siguiente", "Página anterior")
        case .german: ("Nächste Seite", "Vorherige Seite")
        case .french: ("Page suivante", "Page précédente")
        case .portuguese: ("Próxima página", "Página anterior")
        }
        let label = forward ? names.0 : names.1
        return app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }
}
