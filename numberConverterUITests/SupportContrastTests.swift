//
//  SupportContrastTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testSupportNativeContrastInIsolation() throws {
        launch(.english)
        try selectTab(4)
        XCTAssertTrue(try require("support.price.com.mrmaier.NumberConverter.tip.patron").exists)
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "support-before-isolated-contrast-audit"
        before.lifetime = .keepAlways
        add(before)
        auditCapturedScreen(.english, screen: "support-isolated-contrast-audit", auditTypes: .contrast)
        capture(.english, screen: "support-after-isolated-contrast-audit")
        app.terminate()
    }
}
