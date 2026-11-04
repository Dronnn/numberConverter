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
        for (tier, price) in zip(["small", "medium", "large", "extraLarge", "patron"], [3, 9, 19, 49, 99]) {
            let productID = "com.mrmaier.NumberConverter.tip.\(tier)"
            for (prefix, text) in [("tipLabel", "Leave a tip"), ("price", "$\(price).00")] {
                let identifier = "support.\(prefix).\(productID)"
                let label = element(identifier)
                try reveal(label, attempts: 20, identifier: identifier)
                measurements[identifier] = try measureText(label, expectedText: text, name: "\(identifier)-\(name)")
            }
        }
        return measurements
    }
}
