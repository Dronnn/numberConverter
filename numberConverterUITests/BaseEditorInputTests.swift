//
//  BaseEditorInputTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
extension NumberConverterUITests {
    func testBaseEditorRepeatedInvalidEditsUpdateVisibleText() throws {
        launch(.english)
        try selectTab(1)
        try expectValue("allSystems.sourceBase", "10")
        try expectValue("allSystems.targetBase", "2")
        let number = try require("allSystems.number")
        XCTAssertTrue((number.value as? String)?.isEmpty == true || number.value as? String == number.placeholderValue)
        number.tap()
        number.typeText("10")
        dismissKeyboard()
        try expectValue("allSystems.number", "10")
        try expectText("allSystems.result", "1010")
        let field = try require("allSystems.targetBase")
        field.tap()
        for text in ["a", "🙂b"] {
            field.typeText(text)
            try expectValue("allSystems.targetBase", "2")
            try expectText("allSystems.result", "1010")
        }
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "base-editor-repeated-native-invalid-edits-normalized"
        proof.lifetime = .keepAlways
        add(proof)
        app.terminate()
    }
}
