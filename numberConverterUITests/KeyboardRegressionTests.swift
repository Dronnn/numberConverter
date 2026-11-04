//
//  KeyboardRegressionTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testKeyboardDoneAfterInvalidRecovery() throws {
        launch(.english)
        try selectTab(1)
        try replace("allSystems.sourceBase", with: "16")
        dismissKeyboard()
        try expectValue("allSystems.sourceBase", "16")
        for number in ["FF", "G", "FF"] {
            try replace("allSystems.number", with: number)
            try verifyDirectDoneDismissal(stage: number)
        }
        try expectText("allSystems.result", "11111111")
        app.terminate()
    }

    private func verifyDirectDoneDismissal(stage: String) throws {
        let keyboard = app.keyboards.firstMatch
        attachKeyboardState(name: "keyboard-before-Done-\(stage)")
        XCTAssertTrue(keyboard.exists, "Editing must expose a keyboard before Done")
        let before = "before keyboard: \(keyboard.debugDescription)"
        let done = try require("keyboard.done")
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "keyboards.count == 0"), object: app
        )
        let result = XCTWaiter.wait(for: [dismissed], timeout: 3)
        attachKeyboardState(name: "keyboard-after-Done-\(stage)")
        let after = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.debugDescription : "absent"
        let report = XCTAttachment(string: "\(before)\nafter keyboard: \(after)")
        report.name = "keyboard-Done-state-\(stage)"
        report.lifetime = .keepAlways
        add(report)
        XCTAssertEqual(result, .completed)
    }

    private func attachKeyboardState(name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
