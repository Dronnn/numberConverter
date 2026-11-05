//
//  StatisticsContrastTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testStatisticsNativeContrast() throws {
        launch(.english)
        try selectTab(3)
        try tap("quiz.statistics")
        let counts = try require("statistics.counts.all")
        let leaf = XCTAttachment(screenshot: counts.screenshot())
        leaf.name = "statistics-counts-before-contrast"
        leaf.lifetime = .keepAlways
        add(leaf)
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "statistics-screen-before-contrast"
        screen.lifetime = .keepAlways
        add(screen)
        XCTAssertNoThrow(try app.performAccessibilityAudit(for: .contrast))
        app.terminate()
    }
}
