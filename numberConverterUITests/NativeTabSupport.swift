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
            try collectNativeTabs(into: &seen, expected: expected)
            if seen == expected {
                return
            }
            captureNativeTabPageState("inventory-before-\(forward ? "next" : "previous")-page")
            let pager = nativeTabPager(forward: forward, language: language)
            if pager.exists, pager.isHittable {
                pager.tap()
            }
        }
        try collectNativeTabs(into: &seen, expected: expected)
        XCTAssertEqual(seen, expected, "Every one of the five localized native tabs must be reachable")
    }

    func nativeTabButton(at index: Int) throws -> XCUIElement {
        let target = element("app.tab.\(Self.tabIdentifiers[index])")
        let language = try currentLaunchLanguage()
        for forward in [true, false, true] {
            if target.exists, target.isHittable {
                return target
            }
            captureNativeTabPageState("target-\(index)-before-\(forward ? "next" : "previous")-page")
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
        // retain the original Russian regression and also exercise
        // the Portuguese partial-ID failure through the same complete inventory.
        for language in [UITestLanguage.russian, .portuguese] {
            try exerciseLargestNativeTabPaging(language)
        }
    }

    private func exerciseLargestNativeTabPaging(_ language: UITestLanguage) throws {
        launch(language, largeText: true)
        captureNativeTabPageState("\(language.rawValue)-initial-largest-text")
        try expectTabLabels(language)
        let destinations = [
            "converter.input.10", "allSystems.number", "calculator.operandA", "quiz.sidebar", "support.explanation"
        ]
        for (index, identifier) in destinations.enumerated() {
            try selectTab(index)
            XCTAssertTrue(try require(identifier).exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(language.rawValue)-AX-native-tab-paging-\(index)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.terminate()
    }

    private func collectNativeTabs(into seen: inout [String: String], expected: [String: String]) throws {
        let controls = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "app.tab."))
        let elements = controls.allElementsBoundByIndex
        guard Set(elements.map(\.identifier)).count == elements.count else {
            XCTFail("Native tab identifiers must be unique")
            throw UIAuditError.missingElement("unique native tab identifiers")
        }
        for control in elements {
            guard expected[control.identifier] == control.label else {
                XCTFail("Unexpected native tab or translation: \(control.identifier):\(control.label)")
                throw UIAuditError.missingElement(control.identifier)
            }
            seen[control.identifier] = control.label
        }
        if elements.count < expected.count, let bar = completeNativeTabBar(expectedLabels: Array(expected.values)) {
            // some native controls retain IDs while others lose them. every
            // recognized ID was checked before accepting the complete label set.
            let report = XCTAttachment(string: """
            Recognized native IDs: \(elements.map { "\($0.identifier):\($0.label)" }).
            Complete native labels: \(bar.buttons.allElementsBoundByIndex.map(\.label)).
            Verified expected five destinations: \(expected).
            """)
            report.name = "native-tabs-partial-IDs-complete-unique-label-proof"
            report.lifetime = .keepAlways
            add(report)
            captureNativeTabPageState("partial-IDs-complete-labels")
            seen.merge(expected) { _, verified in verified }
        }
    }

    /// iOS occasionally omits TabContent identifiers on a cold, unpinned launch.
    /// a fallback is allowed only inside an actual native tab bar exposing the
    /// complete, uniquely labeled set of five localized controls.
    func fallbackNativeTabControl(identifier: String) -> XCUIElement? {
        guard
            let index = Self.tabIdentifiers.firstIndex(where: { identifier == "app.tab.\($0)" }),
            let language = try? currentLaunchLanguage(),
            let tabBar = completeNativeTabBar(expectedLabels: language.tabLabels) else { return nil }
        let matches = tabBar.buttons.matching(NSPredicate(format: "label == %@", language.tabLabels[index]))
        return matches.count == 1 ? matches.firstMatch : nil
    }

    private func completeNativeTabBar(expectedLabels: [String]) -> XCUIElement? {
        let bars = app.tabBars.allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(app.frame) }
        guard bars.count == 1, let bar = bars.first else { return nil }
        let labels = bar.buttons.allElementsBoundByIndex.map(\.label)
        guard
            labels.count == expectedLabels.count, Set(labels).count == expectedLabels.count,
            Set(labels) == Set(expectedLabels)
        else { return nil }
        return bar
    }

    private func captureNativeTabPageState(_ stage: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "native-tabs-\(stage)-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let buttons = app.buttons.allElementsBoundByIndex.filter(\.exists).map { button in
            let hit = button.identifier == "keyboard.done"
                ? "omitted-known-native-activation-point-issue"
                : String(button.isHittable)
            return "role=\(button.elementType.rawValue); ID=\(button.identifier); label=\(button.label); frame=\(button.frame); hittable=\(hit)"
        }
        let report = XCTAttachment(string: """
        State=\(app.state.rawValue); app=\(app.frame).
        All native buttons (including global pagers and any More control):
        \(buttons.joined(separator: "\n"))
        Complete native hierarchy:
        \(app.debugDescription)
        """)
        report.name = "native-tabs-\(stage)-inventory"
        report.lifetime = .keepAlways
        add(report)
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
