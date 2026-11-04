//
//  NumericInputVisualTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testLargestTextEditedDecimalRendersEveryDigit() throws {
        launch(.english, largeText: true)
        try replace("converter.input.10", with: "1234567890")
        dismissKeyboard()
        try expectValue("converter.input.10", "1234567890")
        let field = try require("converter.input.10")
        try reveal(field, identifier: "converter.input.10")
        revealCompleteNumericInput(field)
        try expectRenderedText(field, expected: "1234567890", name: "edited-decimal-AX5-after-Done")
        app.terminate()
    }

    private func revealCompleteNumericInput(_ field: XCUIElement) {
        let form = app.collectionViews.firstMatch
        let top = app.navigationBars.allElementsBoundByIndex.map(\.frame.maxY).max() ?? app.frame.minY
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? tabBar.frame.minY : app.frame.maxY
        for _ in 0 ..< 6 {
            let frame = field.frame
            if frame.minY >= top, frame.maxY <= bottom {
                return
            }
            if frame.maxY > bottom {
                form.swipeUp(velocity: .slow)
            } else {
                form.swipeDown(velocity: .slow)
            }
        }
        XCTAssertGreaterThanOrEqual(field.frame.minY, top)
        XCTAssertLessThanOrEqual(field.frame.maxY, bottom)
    }
}
