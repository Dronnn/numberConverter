//
//  KeyboardRegressionTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import Vision
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
        guard app.state == .runningForeground else {
            XCTFail("App must be foreground before the observed Done tap")
            return false
        }
        attachKeyboardDoneInventory()
        let query = app.buttons.matching(identifier: "keyboard.done")
        _ = query.firstMatch.waitForExistence(timeout: 1)
        let appFrame = app.frame
        let visible = query.allElementsBoundByIndex.compactMap { button -> (XCUIElement, CGRect)? in
            guard button.exists, button.isEnabled else { return nil }
            let frame = button.frame
            guard
                [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite), !frame.isEmpty,
                appFrame.contains(frame) else { return nil }
            return (button, frame)
        }
        guard visible.count <= 1, app.keyboards.firstMatch.exists else {
            XCTFail("Done requires a unique visible exact-ID Button and a current keyboard context")
            return false
        }
        guard let (button, frame) = visible.first else { return false }
        do {
            try proveKeyboardDonePixels(label: button.label, frame: frame, appFrame: appFrame)
        } catch {
            XCTFail("Cannot prove actual keyboard Done pixels: \(error)")
            return false
        }
        guard button.frame == frame else {
            XCTFail("The observed native Done frame changed before its center tap")
            return false
        }
        XCTContext.runActivity(named: "Tap unique visible keyboard.done at observed frame \(frame)") { _ in
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return true
    }

    private func proveKeyboardDonePixels(label: String, frame: CGRect, appFrame: CGRect) throws {
        guard !label.isEmpty else { throw UIAuditError.missingElement("keyboard.done label") }
        let screen = app.screenshot()
        let fullImage = try XCTUnwrap(UIImage(data: screen.pngRepresentation)?.cgImage)
        let scaleX = CGFloat(fullImage.width) / appFrame.width
        let scaleY = CGFloat(fullImage.height) / appFrame.height
        guard abs(scaleX - scaleY) <= 0.01 else {
            throw UIAuditError.missingElement("keyboard.done screenshot coordinate scale")
        }
        let region = CGRect(
            x: (frame.minX - appFrame.minX) * scaleX,
            y: (frame.minY - appFrame.minY) * scaleY,
            width: frame.width * scaleX,
            height: frame.height * scaleY
        ).integral
        let crop = try XCTUnwrap(fullImage.cropping(to: region))
        let image = XCTAttachment(image: UIImage(cgImage: crop))
        image.name = "keyboard-Done-observed-frame-native-pixels"
        image.lifetime = .keepAlways
        add(image)
        let full = XCTAttachment(screenshot: screen)
        full.name = "keyboard-Done-before-observed-frame-tap"
        full.lifetime = .keepAlways
        add(full)
        let recognized = try recognizeKeyboardDone(in: crop)
        guard recognized.contains(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) else {
            XCTFail("Complete visible Done OCR must match \(label); actual \(recognized)")
            throw UIAuditError.missingElement("keyboard.done visible native text")
        }
    }

    private func recognizeKeyboardDone(in crop: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: crop).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    private func verifyDirectDoneDismissal(stage: String) throws {
        let keyboard = app.keyboards.firstMatch
        attachKeyboardState(name: "keyboard-before-Done-\(stage)")
        attachKeyboardDoneInventory()
        XCTAssertTrue(keyboard.exists, "Editing must expose a keyboard before Done")
        let before = "before keyboard: \(keyboard.debugDescription)"
        let done = try require("keyboard.done")
        XCTAssertTrue(app.frame.contains(done.frame), "The actual native Done control must be inside the app viewport")
        let action = "Done frame: \(done.frame); app frame: \(app.frame); keyboard frame: \(keyboard.frame)"
        XCTAssertTrue(
            tapVisibleKeyboardDone(),
            "Direct Done must use the unique actual visible control without a scroll fallback"
        )
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
            "role=\(element.elementType.rawValue); id=\(element.identifier); label=\(element.label); frame=\(element.frame); exists=\(element.exists); activation-point lookup intentionally omitted after native invalid-point exception; enabled=\(element.isEnabled)"
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
