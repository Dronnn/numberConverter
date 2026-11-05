//
//  numberConverterUITests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import XCTest

@MainActor
final class NumberConverterUITests: XCTestCase {
    let app = XCUIApplication()
    var completedEndToEndWorkflow = false
    var capturesIncludeNativeAudit = true

    override nonisolated func record(_ issue: XCTIssue) {
        defer { super.record(issue) }
        add(NativeAuditIssueDiagnostics.attachment(for: issue, testName: name))
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        // full AX traversals measure about 25 minutes before native audits;
        // the XCTest default is ten minutes. keep short-test defaults intact.
        if name.contains("LargestText"), name.contains("EndToEnd") {
            executionTimeAllowance = 3_600
        } else if name.contains("EndToEnd") {
            executionTimeAllowance = 2_700
        } else if name.contains("testHelpTableRightColumnIsReachableInEveryLanguage") {
            executionTimeAllowance = 1_800
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            capturesIncludeNativeAudit = true
        }
    }

    override func tearDown() async throws {
        let completed = await MainActor.run {
            let result = completedEndToEndWorkflow
            completedEndToEndWorkflow = false
            return result
        }
        if name.contains("EndToEnd") || name.contains("Localization") {
            XCTAssertTrue(completed, "The workflow exited before all required checks completed")
        }
        try await super.tearDown()
    }

    func testEnglishLocalization() throws {
        try exerciseLocalization(.english)
    }

    func testEnglishLargestTextLocalization() throws {
        try exerciseLocalization(.english, largeText: true)
    }

    func testRussianLocalization() throws {
        try exerciseLocalization(.russian)
    }

    func testRussianLargestTextLocalization() throws {
        try exerciseLocalization(.russian, largeText: true)
    }

    func testSpanishLocalization() throws {
        try exerciseLocalization(.spanish)
    }

    func testSpanishLargestTextLocalization() throws {
        try exerciseLocalization(.spanish, largeText: true)
    }

    func testGermanLocalization() throws {
        try exerciseLocalization(.german)
    }

    func testGermanLargestTextLocalization() throws {
        try exerciseLocalization(.german, largeText: true)
    }

    func testFrenchLocalization() throws {
        try exerciseLocalization(.french)
    }

    func testFrenchLargestTextLocalization() throws {
        try exerciseLocalization(.french, largeText: true)
    }

    func testPortugueseLocalization() throws {
        try exerciseLocalization(.portuguese)
    }

    func testPortugueseLargestTextLocalization() throws {
        try exerciseLocalization(.portuguese, largeText: true)
    }

    func testAccessibilityInEveryLanguage() throws {
        for language in UITestLanguage.allCases {
            launch(language)
            for tabIndex in 0 ..< 5 {
                try selectTab(tabIndex)
                capture(language, screen: "accessibility-tab-\(tabIndex)")
            }
            app.terminate()
        }
    }

    func testRotationPreservesQuizAndHelp() throws {
        try exerciseRotation(.english)
    }

    func exerciseLanguage(_ language: UITestLanguage, largeText: Bool = false) throws {
        launch(language, largeText: largeText)
        XCTAssertEqual(app.navigationBars.firstMatch.identifier, language.converterTitle)
        try expectTabLabels(language)
        capture(language, screen: "converter-empty")

        try exerciseConverter(language)
        try exerciseAllSystems(language)
        try exerciseCalculator(language)
        try exerciseQuiz(language)
        try exerciseSupport(language)
        try exerciseHelp(language)
        app.terminate()
    }
}

private enum NativeAuditIssueDiagnostics {
    nonisolated static func attachment(for issue: XCTIssue, testName: String) -> XCTAttachment {
        let location = issue.sourceCodeContext.location
        let lines = [
            "Public XCTest issue metadata; no target is inferred when the audit element is unavailable.",
            "Recorded at Unix seconds: \(Date().timeIntervalSince1970)",
            "Test: \(testName)",
            "Type: \(issue.type); severity: \(issue.severity); isFailure: \(issue.isFailure)",
            "Compact description: \(issue.compactDescription)",
            "Detailed description: \(issue.detailedDescription ?? "nil")",
            "Source location: \(location?.fileURL.path ?? "nil"):\(location?.lineNumber.description ?? "nil")",
            sourceFrames(issue.sourceCodeContext),
            associatedError(issue.associatedError),
            "Attachments: \(issue.attachments.count); listing at most 32 public metadata records.",
            issue.attachments.prefix(32).enumerated().map { index, attachment in
                attachmentMetadata(attachment, index: index)
            }.joined(separator: "\n")
        ]
        let report = lines.map { bounded($0, limit: 8_192) }.joined(separator: "\n")
        let attachment = XCTAttachment(string: bounded(report, limit: 65_536))
        attachment.name = "native-XCTIssue-public-metadata-\(UUID().uuidString)"
        attachment.lifetime = .keepAlways
        return attachment
    }

    nonisolated static func sourceFrames(_ context: XCTSourceCodeContext) -> String {
        let frames = context.callStack.prefix(12).enumerated().map { index, frame in
            let symbol = frame.symbolInfo
            return "Frame\(index): address=0x\(String(frame.address, radix: 16)); "
                + "image=\(symbol?.imageName ?? "nil"); symbol=\(symbol?.symbolName ?? "nil"); "
                + "location=\(symbol?.location?.fileURL.path ?? "nil"):\(symbol?.location?.lineNumber.description ?? "nil")"
        }
        return "Source context frames: \(context.callStack.count); listing at most 12.\n" + frames
            .joined(separator: "\n")
    }

    nonisolated static func associatedError(_ error: (any Error)?) -> String {
        guard let error else { return "Associated error: nil" }
        let nativeError = error as NSError
        return "Associated NSError domain: \(nativeError.domain); code: \(nativeError.code)\n"
            + "Associated NSError userInfo: \(String(describing: nativeError.userInfo))"
    }

    nonisolated static func attachmentMetadata(_ attachment: XCTAttachment, index: Int) -> String {
        "Attachment\(index): name=\(attachment.name ?? "nil"); UTI=\(attachment.uniformTypeIdentifier); "
            + "lifetime=\(attachment.lifetime); userInfo=\(attachment.userInfo.map { String(describing: $0) } ?? "nil")"
    }

    nonisolated static func bounded(_ text: String, limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "\n[metadata truncated]" : text
    }
}
