//
//  SupportStatusTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testPendingTipCanBeDismissedAndFreeConversionStillWorks() throws {
        defer { app.terminate() }
        // existing DEBUG-only UITestTipService returns pending without StoreKit.
        launch(.english, tipStoreState: "pending")
        try selectTab(4)
        let smallTipID = "support.product.com.mrmaier.NumberConverter.tip.small"
        let smallTip = element(smallTipID)
        try reveal(smallTip, container: app.scrollViews.firstMatch, identifier: smallTipID)
        XCTAssertTrue(smallTip.isEnabled)
        XCTAssertFalse(element("support.status").exists)
        try tap(smallTipID)

        let status = element("support.status")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        try reveal(status, container: app.scrollViews.firstMatch, identifier: "support.status")
        let pendingMessage =
            "Your tip is awaiting approval. We will confirm it when the App Store completes the purchase."
        XCTAssertTrue(status.staticTexts[pendingMessage].exists)
        let dismiss = status.buttons["OK"]
        XCTAssertTrue(dismiss.exists && dismiss.isHittable)
        let pendingScreen = XCTAttachment(screenshot: app.screenshot())
        pendingScreen.name = "support-existing-pending-fixture-before-dismiss"
        pendingScreen.lifetime = .keepAlways
        add(pendingScreen)
        dismiss.tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 5), .completed)

        try selectTab(0)
        try useUnsignedBinaryForStatusTests()
        try replace("converter.input.10", with: "255")
        dismissKeyboard()
        try expectValue("converter.input.10", "255")
        try expectValue("converter.input.2", "11111111")
        try expectValue("converter.input.8", "377")
        try expectValue("converter.input.16", "FF")
        XCTAssertTrue(try require("converter.detail.10").isEnabled)
        let freeScreen = XCTAttachment(screenshot: app.screenshot())
        freeScreen.name = "free-converter-after-pending-tip-dismissal"
        freeScreen.lifetime = .keepAlways
        add(freeScreen)
    }

    func testConverterRangeErrorPreservesValidOutputsAndRecovers() throws {
        defer { app.terminate() }
        launch(.english)
        try useUnsignedBinaryForStatusTests()
        let supported = String(repeating: "9", count: 38)
        // independent integer oracle: Python bin(10**38 - 1) / hex(10**38 - 1).
        let supportedBinary =
            "1001011001110110100110010101000010110101000011011000100011110100"
                + "000100110001010001000100011111111111111111111111111111111111111"
        let supportedHex = "4B3B4CA85A86C47A098A223FFFFFFFFF"
        try replace("converter.input.10", with: supported)
        dismissKeyboard()
        try expectValue("converter.input.10", supported)
        try expectValue("converter.input.2", supportedBinary)
        try expectValue("converter.input.16", supportedHex)

        let input = try visibleEditableInput("converter.input.10")
        try tapEditableInput(input, identifier: "converter.input.10")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        // every insertion point produces the same all-nine draft. from the next
        // digit onward, each intermediate value exceeds the supported range.
        input.element.typeText(String(repeating: "9", count: 162))
        let outOfRange = String(repeating: "9", count: 200)
        dismissKeyboard()
        try expectValue("converter.input.10", outOfRange)
        let error = element("converter.error.10")
        try reveal(error, container: app.collectionViews.firstMatch, identifier: "converter.error.10")
        XCTAssertEqual(error.label, "Number exceeds the supported range or precision")
        XCTAssertLessThanOrEqual(try require("converter.input.10").frame.maxY, error.frame.minY)
        XCTAssertFalse(try require("converter.detail.10").isEnabled)
        try expectValue("converter.input.2", supportedBinary)
        try expectValue("converter.input.16", supportedHex)
        let invalidScreen = XCTAttachment(screenshot: app.screenshot())
        invalidScreen.name = "converter-out-of-range-preserves-draft-and-valid-outputs"
        invalidScreen.lifetime = .keepAlways
        add(invalidScreen)

        try replace("converter.input.10", with: "10")
        dismissKeyboard()
        try expectValue("converter.input.10", "10")
        try expectValue("converter.input.2", "1010")
        try expectValue("converter.input.8", "12")
        try expectValue("converter.input.16", "A")
        let errorCleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: error)
        XCTAssertEqual(XCTWaiter.wait(for: [errorCleared], timeout: 5), .completed)
        XCTAssertTrue(try require("converter.detail.10").isEnabled)
    }

    private func useUnsignedBinaryForStatusTests() throws {
        let identifier = "converter.twosComplement"
        let toggle = element(identifier)
        try reveal(toggle, container: app.collectionViews.firstMatch, identifier: identifier)
        let state = try XCTUnwrap(toggle.value as? String, "The native two’s-complement Switch must expose its value")
        XCTAssertTrue(["0", "1"].contains(state), "Unexpected native Switch value: \(state)")
        if state == "1" {
            try tap(identifier)
        }
        let unsigned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [unsigned], timeout: 3), .completed)
    }
}
