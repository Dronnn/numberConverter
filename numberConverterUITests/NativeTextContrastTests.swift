//
//  NativeTextContrastTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
extension NumberConverterUITests {
    func testNativeFinishHasAccessibleRenderedContrast() throws {
        launch(.english)
        try selectTab(3)
        try tap("quiz.category.binaryInt")
        let finish = try require("quiz.finish")
        try reveal(finish, identifier: "quiz.finish")
        XCTAssertTrue(finish.isHittable)
        XCTAssertTrue(app.frame.contains(finish.frame))
        let ratio = try renderedTextContrast(finish, name: "native-finish-independent-pixels")
        XCTAssertGreaterThanOrEqual(ratio, 4.5)
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "native-finish-positive-screen"
        screen.lifetime = .keepAlways
        add(screen)
        try tap("quiz.finish")
        let ended = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element("quiz.session")
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ended], timeout: 5), .completed)
        XCTAssertTrue(try require("quiz.category.binaryInt").isHittable)
        app.terminate()
    }

    func testSupportSmallTipHasAccessibleRenderedContrast() throws {
        launch(.english)
        try selectTab(4)
        let label = try require("support.tipLabel.com.mrmaier.NumberConverter.tip.small")
        let ratio = try renderedTextContrast(label, name: "support-small-tip-independent-pixels")
        XCTAssertGreaterThanOrEqual(ratio, 4.5)
        app.terminate()
    }

    func isMeasuredSupportContrastIssue(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard
            issue.auditType == .contrast, issue.compactDescription == "Contrast failed",
            let element = issue.element, element.exists, element.isHittable, element.elementType == .staticText,
            element.identifier == "support.tipLabel.com.mrmaier.NumberConverter.tip.small"
        else { return false }
        return (try? renderedTextContrast(element, name: "support-small-tip-failure-time-pixels"))
            .map { $0 >= 4.5 } ?? false
    }

    func isMeasuredFinishContrastIssue(_ issue: XCUIAccessibilityAuditIssue, language: UITestLanguage) -> Bool {
        guard
            language == .english,
            issue.auditType == .contrast, issue.compactDescription == "Contrast failed",
            let element = issue.element, element.exists, element.isHittable, element.elementType == .button,
            element.identifier == "quiz.finish", element.label == "Finish", app.frame.contains(element.frame)
        else { return false }
        return (try? renderedTextContrast(element, name: "native-finish-failure-time-pixels"))
            .map { $0 >= 4.5 } ?? false
    }

    private func renderedTextContrast(_ element: XCUIElement, name: String) throws -> Double {
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let image = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation)?.cgImage)
        let colors = try textColorHistogram(image)
        let background = try XCTUnwrap(colors.max { $0.value < $1.value }?.key)
        let backgroundLuminance = colorLuminance(background)
        let foreground = try XCTUnwrap(colors.filter {
            backgroundLuminance > 0.5 ? colorLuminance($0.key) < 0.1 : colorLuminance($0.key) > 0.8
        }.max { $0.value < $1.value }?.key)
        let foregroundLuminance = colorLuminance(foreground)
        let ratio = (max(backgroundLuminance, foregroundLuminance) + 0.05)
            / (min(backgroundLuminance, foregroundLuminance) + 0.05)
        let report = XCTAttachment(string: """
        Actual native text crop: \(image.width)×\(image.height), converted to sRGB for WCAG luminance.
        Most frequent solid foreground: \(String(format: "#%06X", foreground)); background: \(String(format: "#%06X", background)).
        Contrast: \(ratio):1. Anti-alias edge coverage is excluded from solid-color selection.
        """)
        report.name = "\(name)-measurement"
        report.lifetime = .keepAlways
        add(report)
        return ratio
    }

    private func textColorHistogram(_ image: CGImage) throws -> [UInt32: Int] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(try CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var histogram: [UInt32: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index + 3] == 255 {
            let color = UInt32(pixels[index]) << 16 | UInt32(pixels[index + 1]) << 8 | UInt32(pixels[index + 2])
            histogram[color, default: 0] += 1
        }
        return histogram
    }

    private func colorLuminance(_ color: UInt32) -> Double {
        let components = [color >> 16, (color >> 8) & 255, color & 255].map { Double($0) / 255 }
        let linear = components.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
