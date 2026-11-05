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

    func exerciseNavigationSmoke(_ language: UITestLanguage) throws {
        launch(language)
        try expectTabLabels(language)
        for index in 0 ..< 5 {
            try selectTab(index)
            XCTAssertTrue(try require("app.help").isHittable)
            capture(language, screen: "smoke-tab-\(index)")
        }
        try expectText("support.explanation", language.supportExplanation)
        try expectTipPrice(language, identifier: tipIdentifiers[0], amount: "2.99")
        try openHelp()
        capture(language, screen: "smoke-help-modal")
        try closeHelp()
        XCTAssertTrue(try require("support.explanation").exists)
        app.terminate()
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
