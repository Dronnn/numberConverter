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
    /// checks rendered glyphs independently of the element's complete AX value.
    /// line breaks may split a currency amount or a long number between digits.
    func expectRenderedText(_ element: XCUIElement, expected: String, name: String) throws {
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
        request.recognitionLanguages = ["en-US"]
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
