//
//  SupportRegionalPriceTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testSupportIndonesianPriceFitsAtLargestText() throws {
        launch(.english, largeText: true, tipStoreState: "regional-price")
        try selectTab(4)
        let productID = "com.mrmaier.NumberConverter.tip.patron"
        let price = element("support.price.\(productID)")
        try reveal(price, attempts: 20, identifier: "support.price.\(productID)")
        app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        let button = try require("support.product.\(productID)")
        let expected = "Rp\u{00A0}1,999,000.00"
        try expectText("support.price.\(productID)", expected)
        let report = """
        Exact ASC Indonesia USD99-tier price: \(expected)
        AX5 window: \(app.frame)
        Tip button: \(button.frame)
        Rendered price: \(price.frame)
        """
        let measurement = XCTAttachment(string: report)
        measurement.name = "support-Indonesian-price-AX5-frames"
        measurement.lifetime = .keepAlways
        add(measurement)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "support-Indonesian-price-AX5-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(button.frame.contains(price.frame), report)
        XCTAssertTrue(app.frame.contains(price.frame), report)
        try expectRenderedText(price, expected: expected, name: "support-Indonesian-price-AX5-rendered")
        XCTAssertNoThrow(try app.performAccessibilityAudit(for: .textClipped))
        app.terminate()
    }
}
