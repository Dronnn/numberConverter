//
//  HomeScreenNameTests.swift
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
    func testAppShellRendersWithSceneDelegate() throws {
        launch(.english)
        try expectTabLabels(.english)
        XCTAssertTrue(try require("converter.input.10").exists)
        XCTAssertTrue(try require("app.help").isHittable)
        app.terminate()
    }

    func testHomeScreenNameRendersCompletely() throws {
        let expected = ProcessInfo.processInfo.environment["UI_HOME_LABEL_EXPECTED"] ?? "Base Lab"
        app.launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons.matching(identifier: expected).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10), "Missing localized Home Screen icon: \(expected)")
        let crop = icon.screenshot()
        for (suffix, screenshot) in [("icon", crop), ("screen", springboard.screenshot())] {
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "home-label-\(expected)-\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let image = try XCTUnwrap(UIImage(data: crop.pngRepresentation)?.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "ru-RU", "es-ES", "de-DE", "fr-FR", "pt-BR"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let normalized = recognized.map { $0.filter { !$0.isWhitespace }.lowercased() }
        XCTAssertTrue(
            normalized.contains(expected.filter { !$0.isWhitespace }.lowercased()),
            "The complete Home Screen label must be visibly rendered; OCR: \(recognized)"
        )
        app.terminate()
    }

    func testHomeScreenQuickActionsReachWarmAndColdDestinations() throws {
        launch(.english)
        try openSystemQuickAction("Calculator", stage: "warm")
        XCTAssertTrue(try require("calculator.operandA").isHittable)
        XCTAssertTrue(app.navigationBars["Calculator"].exists)
        app.terminate()
        try openSystemQuickAction("Quiz", stage: "cold")
        XCTAssertTrue(try require("quiz.sidebar").isHittable)
        XCTAssertTrue(app.navigationBars["Quiz"].exists)
        app.terminate()
    }

    func testHomeScreenConverterQuickActionsWarmAndCold() throws {
        try exerciseToolQuickAction("Converter", destination: "converter.input.10", startingTab: 2)
    }

    func testHomeScreenAllBasesQuickActionsWarmAndCold() throws {
        try exerciseToolQuickAction("All Bases", destination: "allSystems.number", startingTab: 0)
    }

    func testHomeScreenCalculatorColdAndQuizWarmQuickActions() throws {
        launch(.english)
        app.terminate()
        try openSystemQuickAction("Calculator", stage: "cold")
        XCTAssertTrue(try require("calculator.operandA").isHittable)
        try openSystemQuickAction("Quiz", stage: "warm")
        XCTAssertTrue(try require("quiz.sidebar").isHittable)
        app.terminate()
    }

    private func exerciseToolQuickAction(_ title: String, destination: String, startingTab: Int) throws {
        launch(.english)
        try selectTab(startingTab)
        for stage in ["warm", "cold"] {
            try openSystemQuickAction(title, stage: stage)
            XCTAssertTrue(try require(destination).isHittable)
            app.terminate()
        }
    }

    private func openSystemQuickAction(_ title: String, stage: String) throws {
        if app.state == .runningForeground {
            XCUIDevice.shared.press(.home)
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons.matching(identifier: "Base Lab").firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10))
        for _ in 0 ..< 4 {
            if icon.isHittable {
                break
            }
            if icon.frame.minX < springboard.frame.minX {
                springboard.swipeRight()
            } else {
                springboard.swipeLeft()
            }
        }
        XCTAssertTrue(icon.isHittable)
        icon.press(forDuration: 1.2)
        let action = springboard.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Missing OS quick action: \(title)")
        let menu = XCTAttachment(screenshot: springboard.screenshot())
        menu.name = "quick-action-\(stage)-\(title)-system-menu"
        menu.lifetime = .keepAlways
        add(menu)
        action.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let destination = XCTAttachment(screenshot: app.screenshot())
        destination.name = "quick-action-\(stage)-\(title)-destination"
        destination.lifetime = .keepAlways
        add(destination)
    }
}
