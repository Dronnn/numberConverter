//
//  SupportUIWorkflows.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import XCTest

@MainActor
extension NumberConverterUITests {
    private var tipIdentifiers: [String] {
        ["small", "medium", "large", "extraLarge", "patron"].map {
            "com.mrmaier.NumberConverter.tip.\($0)"
        }
    }

    func exerciseLocalization(_ language: UITestLanguage, largeText: Bool = false) throws {
        // dedicated audits and functional tests cover those concerns separately.
        let originalAuditMode = capturesIncludeNativeAudit
        capturesIncludeNativeAudit = false
        defer {
            app.terminate()
            capturesIncludeNativeAudit = originalAuditMode
        }
        launch(language, largeText: largeText)
        try expectTabLabels(language)
        XCTAssertEqual(app.navigationBars.firstMatch.identifier, language.converterTitle)
        for index in Self.tabIdentifiers.indices {
            try selectTab(index)
            let prefix = Self.tabIdentifiers[index] + "."
            let labels = language.localizationLabels.filter { $0.key.hasPrefix(prefix) }
            for (identifier, expected) in labels.sorted(by: { $0.key < $1.key }) {
                try expectReachableLocalizedLabel(identifier, expected: expected)
            }
            XCTAssertTrue(try require("app.help").isHittable)
            assertNoLocalizationKeys()
            capture(language, screen: "localization-tab-\(index)")
        }
        try expectText("support.explanation", language.supportExplanation)
        for (identifier, amount) in zip(tipIdentifiers, ["2.99", "8.99", "19.99", "49.99", "99.99"]) {
            try expectTipPrice(language, identifier: identifier, amount: amount)
        }
        try exerciseLocalizedHelp(language)
        markWorkflowCompleted(language, largestText: largeText, localization: true)
    }

    private func expectReachableLocalizedLabel(_ identifier: String, expected: String) throws {
        let label = element(identifier)
        try reveal(label, identifier: identifier)
        XCTAssertTrue(label.label.contains(expected), "\(identifier): expected \(expected), actual \(label.label)")
        XCTAssertGreaterThanOrEqual(label.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(label.frame.maxX, app.frame.maxX)
    }

    private func exerciseLocalizedHelp(_ language: UITestLanguage) throws {
        try openHelp()
        try tap("help.topic.1")
        try expectText("help.title", XCTUnwrap(language.localizationLabels["help.title"]))
        assertNoLocalizationKeys()
        capture(language, screen: "localization-help")
        backToList("help.sidebar")
        try tap("help.privacy")
        try expectText("privacy.title", XCTUnwrap(language.localizationLabels["privacy.title"]))
        assertNoLocalizationKeys()
        capture(language, screen: "localization-privacy")
        try closeHelp()
    }

    func exerciseSupport(_ language: UITestLanguage) throws {
        try selectTab(4)
        try expectText("support.explanation", language.supportExplanation)
        let lastProduct = try element("support.product.\(XCTUnwrap(tipIdentifiers.last))")
        try auditScrolling(
            language,
            screen: "support-available",
            container: app.scrollViews.firstMatch,
            through: lastProduct
        )
        for (identifier, amount) in zip(tipIdentifiers, ["2.99", "8.99", "19.99", "49.99", "99.99"]) {
            try expectTipPrice(language, identifier: identifier, amount: amount)
        }
        let largestText = app.launchArguments.contains("UICTContentSizeCategoryAccessibilityXXXL")
        app.terminate()
        launch(language, largeText: largestText, tipStoreState: "retry")
        try selectTab(4)
        try reveal(element("support.retry"), identifier: "support.retry")
        XCTAssertTrue(try require("support.availability").exists)
        capture(language, screen: "support-unavailable")
        try tap("support.retry")
        try expectTipPrice(language, identifier: tipIdentifiers[0], amount: "2.99")
        capture(language, screen: "support-recovered-after-retry")
        XCTAssertFalse(element("support.retry").exists)
    }

    private func expectTipPrice(_ language: UITestLanguage, identifier: String, amount: String) throws {
        let product = element("support.product.\(identifier)")
        try reveal(product, identifier: "support.product.\(identifier)")
        XCTAssertTrue(product.isEnabled)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: language.region)
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let expected = try XCTUnwrap(formatter.string(from: NSDecimalNumber(string: amount)))
        let price = element("support.price.\(identifier)")
        if price.exists {
            try expectText("support.price.\(identifier)", expected)
        } else {
            XCTAssertTrue(product.label.contains(expected), product.label)
        }
    }
}
