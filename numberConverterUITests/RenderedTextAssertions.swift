//
//  RenderedTextAssertions.swift
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
    func selectRenderedDigits(_ field: XCUIElement, expected: String, name: String) throws {
        let screenshot = field.screenshot()
        let crop = XCTAttachment(screenshot: screenshot)
        crop.name = "\(name)-selection-glyph-crop"
        crop.lifetime = .keepAlways
        add(crop)
        let image = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation)?.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let matches = (request.results ?? []).filter { $0.topCandidates(1).first?.string == expected }
        let center: CGVector
        if matches.count == 1, let box = matches.first?.boundingBox {
            center = CGVector(dx: box.midX, dy: 1 - box.midY)
        } else {
            XCTAssertTrue(matches.isEmpty, "The glyph selection must identify exactly one value")
            center = try singleDigitCenter(image, expected: expected, name: name)
        }
        let report =
            XCTAttachment(string: "Existing: \(expected); field frame: \(field.frame); native glyph center: \(center)")
        report.name = "\(name)-selection-glyph-measurement"
        report.lifetime = .keepAlways
        add(report)
        field.coordinate(withNormalizedOffset: center).doubleTap()
        let selected = XCTAttachment(screenshot: app.screenshot())
        selected.name = "\(name)-after-native-glyph-selection"
        selected.lifetime = .keepAlways
        add(selected)
    }

    /// a single right-aligned digit can be ignored by OCR in an extremely wide white field crop.
    /// padding a tight native-ink crop changes recognition context without scaling the glyphs.
    private func singleDigitCenter(_ image: CGImage, expected: String, name: String) throws -> CGVector {
        XCTAssertEqual(expected.count, 1)
        XCTAssertTrue(expected.allSatisfy(\.isNumber))
        let bounds = try nativeDarkInkBounds(image)
        let cropped = try XCTUnwrap(image.cropping(to: bounds))
        let padding = 16.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: bounds.width + padding * 2, height: bounds.height + padding * 2)
        let padded = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: cropped).draw(at: CGPoint(x: padding, y: padding))
        }
        let attachment = XCTAttachment(image: padded)
        attachment.name = "\(name)-single-digit-native-ink-padding"
        attachment.lifetime = .keepAlways
        add(attachment)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(padded.cgImage)).perform([request])
        let matches = (request.results ?? []).filter { $0.topCandidates(1).first?.string == expected }
        XCTAssertEqual(matches.count, 1, "The unchanged native digit must be recognized exactly; no OCR aliases")
        let box = try XCTUnwrap(matches.first).boundingBox
        let xPosition = bounds.minX + box.midX * size.width - padding
        let yPosition = bounds.minY + (1 - box.midY) * size.height - padding
        let measurement =
            XCTAttachment(string: "Native ink bounds: \(bounds); padding:16px; scale:1; exact OCR:\(expected)")
        measurement.name = "\(name)-single-digit-native-ink-measurement"
        measurement.lifetime = .keepAlways
        add(measurement)
        return CGVector(dx: xPosition / CGFloat(image.width), dy: yPosition / CGFloat(image.height))
    }

    private func nativeDarkInkBounds(_ image: CGImage) throws -> CGRect {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        XCTAssertGreaterThan(Double(pixels.filter { $0 >= 245 }.count) / Double(pixels.count), 0.9)
        var minX = image.width
        var minY = image.height
        var maxX = -1
        var maxY = -1
        for (index, pixel) in pixels.enumerated() where pixel < 245 {
            minX = min(minX, index % image.width)
            minY = min(minY, index / image.width)
            maxX = max(maxX, index % image.width)
            maxY = max(maxY, index / image.width)
        }
        XCTAssertGreaterThanOrEqual(maxX, minX)
        XCTAssertGreaterThanOrEqual(maxY, minY)
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// checks rendered glyphs independently of the element's complete AX value.
    /// line breaks may split a currency amount or a long number between digits.
    func expectRenderedText(
        _ element: XCUIElement,
        expected: String,
        name: String,
        recognitionLanguages: [String] = ["en-US"]
    ) throws {
        let screenshot = element.screenshot()
        for (suffix, image) in [("crop", screenshot), ("screen", app.screenshot())] {
            let attachment = XCTAttachment(screenshot: image)
            attachment.name = "\(name)-\(suffix)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let image = try XCTUnwrap(UIImage(data: screenshot.pngRepresentation)?.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = recognizedTextLines(request.results ?? [])
        let rendered = lines.joined().filter { !$0.isWhitespace }.lowercased()
        let complete = expected.filter { !$0.isWhitespace }.lowercased()
        let report = XCTAttachment(string: "Expected: \(expected)\nOCR lines: \(lines)\nFrame: \(element.frame)")
        report.name = "\(name)-OCR"
        report.lifetime = .keepAlways
        add(report)
        XCTAssertEqual(rendered, complete, "The entire value must remain rendered after editing")
    }

    private func recognizedTextLines(_ observations: [VNRecognizedTextObservation]) -> [String] {
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations.sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            if
                let last = rows.last?.first,
                abs(last.boundingBox.midY - observation.boundingBox.midY)
                < min(last.boundingBox.height, observation.boundingBox.height) * 0.5
            {
                rows[rows.count - 1].append(observation)
            } else {
                rows.append([observation])
            }
        }
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        }
    }
}
