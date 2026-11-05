//
//  SupportDynamicTypeTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testSupportReviewScreenshot() throws {
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        launch(.english)
        try selectTab(4)
        try expectText("support.explanation", UITestLanguage.english.supportExplanation)
        var frames: [String] = []
        for (tier, amount) in zip(
            ["small", "medium", "large", "extraLarge", "patron"],
            ["2.99", "8.99", "19.99", "49.99", "99.99"]
        ) {
            let identifier = "support.price.com.mrmaier.NumberConverter.tip.\(tier)"
            try expectText(identifier, "$\(amount)")
            let price = try require(identifier)
            XCTAssertTrue(price.isHittable, identifier)
            XCTAssertTrue(app.frame.contains(price.frame), "\(identifier): \(price.frame)")
            frames.append("$\(amount): \(price.frame)")
        }
        XCTAssertEqual(app.keyboards.count, 0)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "support-review-en-v2"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let proof = XCTAttachment(string: "Verified all five current USD prices, no purchase actions.\n" + frames
            .joined(separator: "\n"))
        proof.name = "support-review-en-v2-prices"
        proof.lifetime = .keepAlways
        add(proof)
        app.terminate()
    }

    func testSupportTipLabelsScaleAtLargestText() throws {
        let normal = try measureSupportTips(category: "UICTContentSizeCategoryL", name: "normal")
        let largest = try measureSupportTips(category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5")
        for identifier in normal.keys.sorted() {
            let initial = try XCTUnwrap(normal[identifier])
            let enlarged = try XCTUnwrap(largest[identifier])
            let report = """
            Support text: \(identifier)
            normal frame: \(initial.frame), glyph height: \(initial.glyphHeight) pixels
            AX5 frame: \(enlarged.frame), glyph height: \(enlarged.glyphHeight) pixels
            frame height growth: \(enlarged.frame.height / initial.frame.height)
            glyph height growth: \(enlarged.glyphHeight / initial.glyphHeight)
            """
            let attachment = XCTAttachment(string: report)
            attachment.name = "\(identifier)-dynamic-type-measurements"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertGreaterThan(enlarged.frame.height, initial.frame.height * 1.25, report)
            XCTAssertGreaterThan(enlarged.glyphHeight, initial.glyphHeight * 1.4, report)
        }
        app.terminate()
    }

    private func measureSupportTips(category: String, name: String) throws -> [String: TextScaleMeasurement] {
        launchTextMeasurement(category: category)
        try selectTab(4)
        var measurements: [String: TextScaleMeasurement] = [:]
        for (tier, price) in zip(
            ["small", "medium", "large", "extraLarge", "patron"],
            ["2.99", "8.99", "19.99", "49.99", "99.99"]
        ) {
            let productID = "com.mrmaier.NumberConverter.tip.\(tier)"
            for (prefix, text) in [("tipLabel", "Leave a tip"), ("price", "$\(price)")] {
                let identifier = "support.\(prefix).\(productID)"
                let label = element(identifier)
                try reveal(label, attempts: 20, identifier: identifier)
                measurements[identifier] = try measureText(label, expectedText: text, name: "\(identifier)-\(name)")
            }
        }
        return measurements
    }
}
