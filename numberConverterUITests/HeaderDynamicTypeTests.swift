//
//  HeaderDynamicTypeTests.swift
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
    func testSettingsHeaderScalesAtLargestText() throws {
        let normal = try measureSettingsHeader(category: "UICTContentSizeCategoryL", name: "normal")
        let largest = try measureSettingsHeader(category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5")
        let report = """
        normal header frame: \(normal.frame)
        normal Settings glyph height: \(normal.glyphHeight) pixels
        AX5 header frame: \(largest.frame)
        AX5 Settings glyph height: \(largest.glyphHeight) pixels
        frame height growth: \(largest.frame.height / normal.frame.height)
        glyph height growth: \(largest.glyphHeight / normal.glyphHeight)
        """
        let attachment = XCTAttachment(string: report)
        attachment.name = "settings-header-dynamic-type-measurements"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertGreaterThan(largest.frame.height, normal.frame.height * 1.25, report)
        XCTAssertGreaterThan(largest.glyphHeight, normal.glyphHeight * 1.4, report)
        app.terminate()
    }

    func testDynamicTypeAuditWithSettingsVisible() throws {
        launch(.english)
        let settings = app.staticTexts["Settings"]
        try reveal(settings, identifier: "Settings")
        centerSettingsHeader()
        XCTAssertTrue(settings.isHittable)
        attachHeaderScreenshot(settings, name: "settings-visible-before-native-dynamic-type-audit")
        capture(.english, screen: "settings-visible-native-audit")
        app.terminate()
    }

    func testResultRowScalesAtLargestText() throws {
        for (prefix, tabIndex) in [("allSystems", 1), ("calculator", 2)] {
            try assertResultRowGrowth(prefix: prefix, tabIndex: tabIndex)
        }
        app.terminate()
    }

    func testCalculatorResultBaseLabelScalesAtLargestText() throws {
        let normal = try measureCalculatorBaseLabel(category: "UICTContentSizeCategoryL", name: "normal")
        let largest = try measureCalculatorBaseLabel(
            category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5"
        )
        let report = """
        normal Number base label frame: \(normal.frame), glyph height: \(normal.glyphHeight) pixels
        AX5 Number base label frame: \(largest.frame), glyph height: \(largest.glyphHeight) pixels
        label frame height growth: \(largest.frame.height / normal.frame.height)
        label glyph height growth: \(largest.glyphHeight / normal.glyphHeight)
        """
        let attachment = XCTAttachment(string: report)
        attachment.name = "calculator-result-base-label-dynamic-type-measurements"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(largest.frame.height, normal.frame.height * 1.25, report)
        XCTAssertGreaterThan(largest.glyphHeight, normal.glyphHeight * 1.4, report)
        app.terminate()
    }

    func testQuizStatisticsLinkLabelScalesAtLargestText() throws {
        let normal = try measureQuizStatisticsLabel(category: "UICTContentSizeCategoryL", name: "normal")
        let largest = try measureQuizStatisticsLabel(
            category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5"
        )
        let report = """
        normal Overall statistics label frame: \(normal.frame), glyph height: \(normal.glyphHeight) pixels
        AX5 Overall statistics label frame: \(largest.frame), glyph height: \(largest.glyphHeight) pixels
        label frame height growth: \(largest.frame.height / normal.frame.height)
        label glyph height growth: \(largest.glyphHeight / normal.glyphHeight)
        """
        let attachment = XCTAttachment(string: report)
        attachment.name = "quiz-statistics-link-label-dynamic-type-measurements"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(largest.frame.height, normal.frame.height * 1.25, report)
        XCTAssertGreaterThan(largest.glyphHeight, normal.glyphHeight * 1.4, report)
        app.terminate()
    }

    private func measureQuizStatisticsLabel(category: String, name: String) throws -> TextScaleMeasurement {
        launchTextMeasurement(category: category)
        try selectTab(3)
        let identifier = "quiz.statisticsLabel"
        let label = element(identifier)
        try reveal(label, attempts: 20, identifier: identifier)
        centerSettingsHeader()
        return try measureText(label, expectedText: "Overall statistics", name: "quiz-statistics-label-\(name)")
    }

    private func measureCalculatorBaseLabel(category: String, name: String) throws -> TextScaleMeasurement {
        launchTextMeasurement(category: category)
        try selectTab(2)
        let label = element("calculator.resultBaseLabel")
        try reveal(label, attempts: 20, identifier: "calculator.resultBaseLabel")
        centerSettingsHeader()
        return try measureText(label, expectedText: "Number base", name: "calculator-result-base-label-\(name)")
    }

    private func assertResultRowGrowth(prefix: String, tabIndex: Int) throws {
        let normal = try measureResultRow(
            category: "UICTContentSizeCategoryL", name: "normal", prefix: prefix, tabIndex: tabIndex
        )
        let largest = try measureResultRow(
            category: "UICTContentSizeCategoryAccessibilityXXXL", name: "AX5", prefix: prefix, tabIndex: tabIndex
        )
        let report = """
        ResultRow context: \(prefix)
        normal Result label frame: \(normal.label.frame), glyph height: \(normal.label.glyphHeight) pixels
        AX5 Result label frame: \(largest.label.frame), glyph height: \(largest.label.glyphHeight) pixels
        normal result 0 frame: \(normal.value.frame), glyph height: \(normal.value.glyphHeight) pixels
        AX5 result 0 frame: \(largest.value.frame), glyph height: \(largest.value.glyphHeight) pixels
        label glyph growth: \(largest.label.glyphHeight / normal.label.glyphHeight)
        value glyph growth: \(largest.value.glyphHeight / normal.value.glyphHeight)
        value glyph heights use dark-pixel ink bounds on a verified light cell background, independent of OCR.
        """
        let attachment = XCTAttachment(string: report)
        attachment.name = "\(prefix)-result-row-dynamic-type-measurements"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(largest.label.frame.height, normal.label.frame.height * 1.25, report)
        XCTAssertGreaterThan(largest.value.frame.height, normal.value.frame.height * 1.25, report)
        XCTAssertGreaterThan(largest.label.glyphHeight, normal.label.glyphHeight * 1.4, report)
        XCTAssertGreaterThan(largest.value.glyphHeight, normal.value.glyphHeight * 1.4, report)
    }

    private func launchTextMeasurement(category: String) {
        app.terminate()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", category,
            "-ui-tip-store", "available"
        ]
        app.launch()
    }

    private func measureSettingsHeader(category: String, name: String) throws -> TextScaleMeasurement {
        launchTextMeasurement(category: category)
        let settings = app.staticTexts["Settings"]
        try reveal(settings, attempts: 20, identifier: "Settings")
        centerSettingsHeader()
        return try measureText(settings, expectedText: "Settings", name: "settings-header-\(name)")
    }

    private func measureResultRow(
        category: String,
        name: String,
        prefix: String,
        tabIndex: Int
    ) throws -> (label: TextScaleMeasurement, value: TextScaleMeasurement) {
        launchTextMeasurement(category: category)
        try selectTab(tabIndex)
        if prefix == "calculator" {
            try replace("calculator.operandA", with: "0")
            try replace("calculator.operandB", with: "0")
            dismissKeyboard()
            try tapOperation("+")
        }
        let label = element("\(prefix).resultLabel")
        try reveal(label, attempts: 20, identifier: "\(prefix).resultLabel")
        centerSettingsHeader()
        let value = try require("\(prefix).result")
        XCTAssertEqual(value.label, "0")
        return try (
            label: measureText(label, expectedText: "Result", name: "\(prefix)-result-label-\(name)"),
            value: measureText(value, expectedText: "0", name: "\(prefix)-result-value-\(name)")
        )
    }

    private func measureText(
        _ element: XCUIElement,
        expectedText: String,
        name: String
    ) throws -> TextScaleMeasurement {
        XCTAssertTrue(element.isHittable)
        XCTAssertTrue(element.frame.height.isFinite)
        XCTAssertGreaterThan(element.frame.height, 0)
        attachHeaderScreenshot(element, name: name)
        return try TextScaleMeasurement(
            frame: element.frame,
            glyphHeight: glyphHeight(in: element.screenshot(), expectedText: expectedText)
        )
    }

    private func centerSettingsHeader() {
        let form = app.collectionViews.firstMatch
        form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(
            forDuration: 0.1,
            thenDragTo: form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
            withVelocity: .slow,
            thenHoldForDuration: 0.1
        )
    }

    private func attachHeaderScreenshot(_ header: XCUIElement, name: String) {
        let headerAttachment = XCTAttachment(screenshot: header.screenshot())
        headerAttachment.name = name
        headerAttachment.lifetime = .keepAlways
        add(headerAttachment)
        let screenAttachment = XCTAttachment(screenshot: app.screenshot())
        screenAttachment.name = "\(name)-screen"
        screenAttachment.lifetime = .keepAlways
        add(screenAttachment)
    }

    private func glyphHeight(in screenshot: XCUIScreenshot, expectedText: String) throws -> CGFloat {
        let image = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation)?.cgImage)
        if expectedText == "0" {
            return try darkInkHeight(in: image)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let expected = expectedText.lowercased()
        if let phrase = request.results?.first(where: {
            guard let text = $0.topCandidates(1).first?.string.lowercased() else { return false }
            return text == expected
        }) {
            return phrase.boundingBox.height * CGFloat(image.height)
        }
        // a label may wrap onto multiple lines at AX5. measure the largest
        // recognized line's ink, rather than counting spacing as font growth.
        let expectedWords = Set(expected.split(whereSeparator: \.isWhitespace).map(String.init))
        let lines = (request.results ?? []).filter { observation in
            guard let text = observation.topCandidates(1).first?.string.lowercased() else { return false }
            let words = Set(text.split(whereSeparator: \.isWhitespace).map(String.init))
            return !words.isEmpty && words.isSubset(of: expectedWords)
        }
        let recognizedWords = Set(lines.flatMap {
            ($0.topCandidates(1).first?.string.lowercased() ?? "").split(whereSeparator: \.isWhitespace)
                .map(String.init)
        })
        XCTAssertEqual(recognizedWords, expectedWords, "OCR must recognize the complete rendered label")
        return try XCTUnwrap(lines.map(\.boundingBox.height).max()) * CGFloat(image.height)
    }

    private func darkInkHeight(in image: CGImage) throws -> CGFloat {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        return try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var firstInkRow: Int?
            var lastInkRow: Int?
            var lightPixels = 0
            for row in 0 ..< height {
                for column in 0 ..< width {
                    let offset = (row * width + column) * 4
                    let channels = [bytes[offset], bytes[offset + 1], bytes[offset + 2]]
                    if channels.allSatisfy({ $0 > 200 }) {
                        lightPixels += 1
                    }
                    if channels.allSatisfy({ $0 < 128 }) {
                        firstInkRow = firstInkRow ?? row
                        lastInkRow = row
                    }
                }
            }
            XCTAssertGreaterThan(lightPixels, width * height / 2, "Ink measurement requires a light cell background")
            let first = try XCTUnwrap(firstInkRow, "The result crop contains no dark glyph pixels")
            let last = try XCTUnwrap(lastInkRow)
            return CGFloat(last - first + 1)
        }
    }
}

private struct TextScaleMeasurement {
    let frame: CGRect
    let glyphHeight: CGFloat
}
