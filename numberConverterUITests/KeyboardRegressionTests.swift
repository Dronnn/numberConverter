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
    func testBaseEditorDoneDismissesKeyboardDirectly() throws {
        launch(.english)
        try selectTab(1)
        try replace("allSystems.sourceBase", with: "16")
        try expectValue("allSystems.sourceBase", "16")
        try verifyDirectDoneDismissal(stage: "source-base-16")
        try expectValue("allSystems.sourceBase", "16")
        app.terminate()
    }

    func testTabletKeyboardReplacementAfterInvalidRecovery() throws {
        launch(.english)
        try selectTab(1)
        try replace("allSystems.sourceBase", with: "16")
        try expectValue("allSystems.sourceBase", "16")
        try replace("allSystems.targetBase", with: "10")
        try expectValue("allSystems.targetBase", "10")
        for number in ["FF", "G", "FF"] {
            try replace("allSystems.number", with: number)
            dismissKeyboard()
            try expectValue("allSystems.number", number)
            if number == "G" {
                XCTAssertTrue(try require("allSystems.error").exists)
            } else {
                try expectText("allSystems.result", "255")
            }
        }
        app.terminate()
    }

    func testKeyboardDoneAfterInvalidRecovery() throws {
        launch(.english)
        try selectTab(1)
        try expectValue("allSystems.sourceBase", "10")
        try expectValue("allSystems.targetBase", "2")
        for number in ["255", "G", "255"] {
            try replace("allSystems.number", with: number)
            // the test typing API can switch iPad to a hardware-keyboard accessory.
            // a fresh touch requests the software keyboard again before the
            // unchanged software-keyboard dismissal precondition is checked.
            try require("allSystems.number").tap()
            try verifyDirectDoneDismissal(stage: number)
            try expectValue("allSystems.number", number)
            if number == "G" {
                XCTAssertTrue(try require("allSystems.error").exists)
            } else {
                try expectText("allSystems.result", "11111111")
            }
        }
        app.terminate()
    }

    func tapVisibleKeyboardDone() -> Bool {
        XCTAssertEqual(app.state, .runningForeground)
        attachKeyboardDoneInventory()
        let query = app.buttons.matching(identifier: "keyboard.done")
        _ = query.firstMatch.waitForExistence(timeout: 1)
        let appFrame = app.frame
        let visible = query.allElementsBoundByIndex.compactMap { button -> (XCUIElement, CGRect)? in
            guard button.exists, button.isHittable else { return nil }
            let frame = button.frame
            guard !frame.isEmpty, appFrame.contains(frame) else { return nil }
            return (button, frame)
        }
        XCTAssertLessThanOrEqual(visible.count, 1, "Exactly one visible keyboard Done control may be targeted")
        guard let (_, frame) = visible.first else { return false }
        XCTContext.runActivity(named: "Tap unique visible keyboard.done at observed frame \(frame)") { _ in
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: frame.midX - appFrame.minX,
                dy: frame.midY - appFrame.minY
            )).tap()
        }
        return true
    }

    private func verifyDirectDoneDismissal(stage: String) throws {
        let keyboard = app.keyboards.firstMatch
        attachKeyboardState(name: "keyboard-before-Done-\(stage)")
        attachKeyboardDoneInventory()
        XCTAssertTrue(keyboard.exists, "Editing must expose a keyboard before Done")
        let before = "before keyboard: \(keyboard.debugDescription)"
        let done = try require("keyboard.done")
        try reveal(done, identifier: "keyboard.done")
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(app.frame.contains(done.frame), "The actual native Done control must be inside the app viewport")
        let action = "Done frame: \(done.frame); app frame: \(app.frame); keyboard frame: \(keyboard.frame); hittable: \(done.isHittable)"
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "keyboards.count == 0"), object: app
        )
        let result = XCTWaiter.wait(for: [dismissed], timeout: 3)
        attachKeyboardState(name: "keyboard-after-Done-\(stage)")
        let after = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.debugDescription : "absent"
        let report = XCTAttachment(string: "\(action)\n\(before)\nafter keyboard: \(after)")
        report.name = "keyboard-Done-state-\(stage)"
        report.lifetime = .keepAlways
        add(report)
        XCTAssertEqual(result, .completed)
    }

    private func attachKeyboardDoneInventory() {
        let matches = app.descendants(matching: .any).matching(identifier: "keyboard.done")
            .allElementsBoundByIndex
        let lines = matches.map { element in
            "role=\(element.elementType.rawValue); id=\(element.identifier); label=\(element.label); frame=\(element.frame); exists=\(element.exists); hittable=\(element.isHittable); enabled=\(element.isEnabled)"
        }
        let report =
            XCTAttachment(
                string: "App state=\(app.state.rawValue); frame=\(app.frame); keyboards=\(app.keyboards.count).\nExact keyboard.done matches=\(matches.count):\n" +
                    lines.joined(separator: "\n")
            )
        report.name = "keyboard-Done-exact-ID-role-frame-inventory"
        report.lifetime = .keepAlways
        add(report)
        attachKeyboardState(name: "keyboard-Done-inventory-screen")
    }

    private func attachKeyboardState(name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
