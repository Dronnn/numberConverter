//
//  StoreScreenshotTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testEnglishStoreScreenshots() throws {
        try captureStoreScreenshots(.english)
    }

    func testRussianStoreScreenshots() throws {
        try captureStoreScreenshots(.russian)
    }

    func testSpanishStoreScreenshots() throws {
        try captureStoreScreenshots(.spanish)
    }

    func testGermanStoreScreenshots() throws {
        try captureStoreScreenshots(.german)
    }

    func testFrenchStoreScreenshots() throws {
        try captureStoreScreenshots(.french)
    }

    func testPortugueseStoreScreenshots() throws {
        try captureStoreScreenshots(.portuguese)
    }

    private func captureStoreScreenshots(_ language: UITestLanguage) throws {
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        launch(language, tipStoreState: nil)
        XCTAssertFalse(app.launchArguments.contains("-ui-tip-store"))
        var capturedScreens: Set<String> = []
        try captureStoreToolScreens(language, capturedScreens: &capturedScreens)

        try selectTab(3)
        try tap("quiz.category.binaryInt")
        XCTAssertTrue(try require("quiz.header").isHittable)
        XCTAssertFalse(try require("quiz.question").label.isEmpty)
        try expectValue("quiz.answer", "")
        captureStoreScreen(language, screen: "quiz", capturedScreens: &capturedScreens)

        try openHelp()
        try tap("help.topic.4")
        XCTAssertTrue(try require("help.title").isHittable)
        let formulaIdentifier = "help.block.help.page4.p4"
        let formula = try require(formulaIdentifier)
        try reveal(formula, container: require("help.content"), identifier: formulaIdentifier)
        XCTAssertTrue(formula.label.contains("1*2^4 = 16"), formula.label)
        captureStoreScreen(language, screen: "help", capturedScreens: &capturedScreens)

        XCTAssertEqual(capturedScreens, Set(["converter", "bases", "calculator", "quiz", "help"]))
        XCTAssertEqual(capturedScreens.count, 5)
        let completion = XCTAttachment(string: """
        Store screenshots completed for locale: \(language.rawValue)
        Captured screens: \(capturedScreens.sorted().joined(separator: ", "))
        Capture count: \(capturedScreens.count)
        Text size: UICTContentSizeCategoryL
        StoreKit: production service; no UI tip fixture or purchase actions
        Native accessibility audits run separately.
        """)
        completion.name = "store-screenshots-completed-\(language.rawValue)"
        completion.lifetime = .keepAlways
        add(completion)
        try closeHelp()
        app.terminate()
    }

    private func captureStoreToolScreens(_ language: UITestLanguage, capturedScreens: inout Set<String>) throws {
        let toggle = try require("converter.twosComplement")
        if toggle.value as? String == "1" {
            try tap("converter.twosComplement")
        }
        try replace("converter.input.10", with: "255")
        dismissKeyboard()
        try expectValue("converter.input.2", "11111111")
        try expectValue("converter.input.8", "377")
        try expectValue("converter.input.10", "255")
        try expectValue("converter.input.16", "FF")
        captureStoreScreen(language, screen: "converter", capturedScreens: &capturedScreens)

        try selectTab(1)
        try replace("allSystems.sourceBase", with: "16")
        try expectValue("allSystems.targetBase", "10")
        try replace("allSystems.number", with: "FF")
        dismissKeyboard()
        try expectText("allSystems.result", "255")
        captureStoreScreen(language, screen: "bases", capturedScreens: &capturedScreens)

        try selectTab(2)
        try expectValue("calculator.baseA", "10")
        try expectValue("calculator.baseB", "10")
        try expectValue("calculator.resultBase", "10")
        try replace("calculator.operandA", with: "19")
        try replace("calculator.operandB", with: "5")
        dismissKeyboard()
        try tapOperation("+")
        try expectText("calculator.result", "24")
        captureStoreScreen(language, screen: "calculator", capturedScreens: &capturedScreens)
    }

    private func captureStoreScreen(
        _ language: UITestLanguage,
        screen: String,
        capturedScreens: inout Set<String>
    ) {
        assertNoLocalizationKeys()
        XCTAssertTrue(capturedScreens.insert(screen).inserted, "Duplicate store screenshot: \(screen)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "store-\(language.rawValue)-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
