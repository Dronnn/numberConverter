//
//  SnapshotReferenceTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import SnapshotTesting
import UIKit
import XCTest

@MainActor
final class SnapshotReferenceTests: XCTestCase {
    private let logicalFilename = "test_snapshot.sample.png"
    private let abcHash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    func testSourceUnavailableUsesActualBundledReferenceImages() throws {
        let location = snapshotReferenceLocation(sourceFile: "/unavailable-checkout/SnapshotTests.swift")
        let manifest = try SnapshotReferenceManifest(contentsOf: location.manifestURL)
        let reference = try manifest.resolve(
            logicalFilename: "test_converter.converter-en-light-compact.png",
            runtime: "27.0",
            directory: location.directory
        )
        XCTAssertGreaterThan(try Data(contentsOf: reference.fileURL).count, 1_000)
        XCTAssertEqual(reference.reviewState, .reviewed)
    }

    func testAvailableSourceAndExplicitBundleModeUseTheSameManifestPolicy() throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("SnapshotTests.swift")
        try Data("// snapshot source fixture".utf8).write(to: source)
        let local = snapshotReferenceLocation(sourceFile: source.path)
        let bundled = snapshotReferenceLocation(sourceFile: source.path, forcingBundled: true)
        XCTAssertEqual(local.directory.path, directory.appendingPathComponent("__Snapshots__/SnapshotTests").path)
        XCTAssertNotEqual(local.directory, bundled.directory)
        try FileManager.default.createDirectory(at: local.directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: local.manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: bundled.manifestURL, to: local.manifestURL)
        let filename = "test_converter.converter-en-light-compact.png"
        let localManifest = try SnapshotReferenceManifest(contentsOf: local.manifestURL)
        let bundledManifest = try SnapshotReferenceManifest(contentsOf: bundled.manifestURL)
        let referenceFilenames = Set(bundledManifest.runtimes.values.compactMap { $0.references[filename]?.filename })
        for referenceFilename in referenceFilenames {
            try FileManager.default.copyItem(
                at: bundled.directory.appendingPathComponent(referenceFilename),
                to: local.directory.appendingPathComponent(referenceFilename)
            )
        }
        XCTAssertEqual(localManifest.sha256, bundledManifest.sha256)
        XCTAssertEqual(localManifest.runtimes, bundledManifest.runtimes)
        for runtime in localManifest.runtimes.keys {
            let localReference = try localManifest.resolve(
                logicalFilename: filename, runtime: runtime, directory: local.directory
            )
            let bundledReference = try bundledManifest.resolve(
                logicalFilename: filename, runtime: runtime, directory: bundled.directory
            )
            XCTAssertEqual(localReference.snapshotName, bundledReference.snapshotName)
            XCTAssertEqual(localReference.reviewState, bundledReference.reviewState)
        }
    }

    func testEveryReviewedRuntimeReferenceIsBundledWithItsExactManifestHash() throws {
        let location = snapshotReferenceLocation(sourceFile: "/unavailable-checkout/SnapshotTests.swift")
        let manifest = try SnapshotReferenceManifest(contentsOf: location.manifestURL)
        let originals = try XCTUnwrap(manifest.runtimes["27.0"])
        XCTAssertEqual(originals.references.count, 1_112)
        XCTAssertEqual(Set(manifest.runtimes.keys), ["27.0", "27.2"])
        for (runtime, profile) in manifest.runtimes {
            XCTAssertEqual(Set(profile.references.keys), Set(originals.references.keys))
            XCTAssertEqual(profile.reviewState, .reviewed)
            let overrideCount = profile.references.filter { $0.key != $0.value.filename }.count
            XCTAssertEqual(overrideCount, runtime == "27.0" ? 0 : 332)
            for filename in profile.references.keys.sorted() {
                let reference = try manifest.resolve(
                    logicalFilename: filename, runtime: runtime, directory: location.directory
                )
                XCTAssertTrue(reference.reviewState.permitsAcceptance)
                if runtime == "27.0" {
                    XCTAssertEqual(reference.fileURL.lastPathComponent, filename)
                }
            }
        }
    }

    func testOnlyExactConfiguredRuntimeVersionsAreSupported() throws {
        let manifest = try SnapshotReferenceManifest(data: fixtureManifest())
        let directory = try temporaryDirectory()
        for runtime in ["27.0.0", "27.2.1", "27.3", "28.0", ""] {
            XCTAssertThrowsError(try manifest.resolve(
                logicalFilename: logicalFilename, runtime: runtime, directory: directory
            )) { error in
                XCTAssertEqual(error as? SnapshotReferenceError, .unsupportedRuntime(runtime))
            }
        }
    }

    func testMissingRuntimeCaseAndIncompleteProfileFailExplicitly() throws {
        let manifest = try SnapshotReferenceManifest(data: fixtureManifest(includesSecondRuntime: false))
        let directory = try temporaryDirectory()
        XCTAssertThrowsError(try manifest.resolve(
            logicalFilename: logicalFilename, runtime: "27.2", directory: directory
        )) { error in
            XCTAssertEqual(error as? SnapshotReferenceError, .unsupportedRuntime("27.2"))
        }
        XCTAssertThrowsError(try manifest.resolve(
            logicalFilename: "test_snapshot.unmapped.png", runtime: "27.0", directory: directory
        )) { error in
            XCTAssertEqual(
                error as? SnapshotReferenceError,
                .missingCase(runtime: "27.0", filename: "test_snapshot.unmapped.png")
            )
        }
        XCTAssertThrowsError(try SnapshotReferenceManifest(
            data: fixtureManifest(hasCompleteSecondProfile: false)
        )) { error in
            XCTAssertEqual(
                error as? SnapshotReferenceError,
                .invalidManifest("Incomplete logical-case mapping for iOS27.2")
            )
        }
    }

    func testMissingOverrideNeverFallsBackToAnExistingOriginal() throws {
        let directory = try temporaryDirectory()
        try Data("abc".utf8).write(to: directory.appendingPathComponent(logicalFilename))
        let qualified = "test_snapshot.sample-ios27-2.png"
        let manifest = try SnapshotReferenceManifest(data: fixtureManifest(
            secondReferences: [logicalFilename: ["filename": qualified, "sha256": abcHash]]
        ))
        XCTAssertThrowsError(try manifest.resolve(
            logicalFilename: logicalFilename, runtime: "27.2", directory: directory
        )) { error in
            XCTAssertEqual(
                error as? SnapshotReferenceError,
                .missingFile(directory.appendingPathComponent(qualified).path)
            )
        }
    }

    func testChangedReferenceBytesFailEvenWhenTheFilenameExists() throws {
        let directory = try temporaryDirectory()
        try Data("changed bytes".utf8).write(to: directory.appendingPathComponent(logicalFilename))
        let manifest = try SnapshotReferenceManifest(data: fixtureManifest())
        XCTAssertThrowsError(try manifest.resolve(
            logicalFilename: logicalFilename, runtime: "27.0", directory: directory
        )) { error in
            guard case let .wrongHash(filename, expected, actual) = error as? SnapshotReferenceError else {
                return XCTFail("Expected an explicit reference hash failure, got \(error)")
            }
            XCTAssertEqual(filename, logicalFilename)
            XCTAssertEqual(expected, abcHash)
            XCTAssertNotEqual(actual, abcHash)
        }
    }

    func testQualifiedOverrideAndDiagnosticAcceptanceRemainDistinct() throws {
        let directory = try temporaryDirectory()
        let qualified = "test_snapshot.sample-ios27-2.png"
        try Data("abc".utf8).write(to: directory.appendingPathComponent(logicalFilename))
        try Data("abc".utf8).write(to: directory.appendingPathComponent(qualified))
        let reviewed = try SnapshotReferenceManifest(data: fixtureManifest(
            secondReferences: [logicalFilename: ["filename": qualified, "sha256": abcHash]],
            secondReviewState: "reviewed"
        ))
        let override = try reviewed.resolve(logicalFilename: logicalFilename, runtime: "27.2", directory: directory)
        XCTAssertEqual(override.fileURL.lastPathComponent, qualified)
        XCTAssertEqual(override.snapshotName, "sample-ios27-2")
        XCTAssertTrue(override.reviewState.permitsAcceptance)
        let diagnostic = try SnapshotReferenceManifest(data: fixtureManifest())
        let shared = try diagnostic.resolve(logicalFilename: logicalFilename, runtime: "27.2", directory: directory)
        XCTAssertEqual(shared.fileURL.lastPathComponent, logicalFilename)
        XCTAssertEqual(shared.snapshotName, "sample")
        XCTAssertEqual(shared.reviewState, .diagnostic)
        XCTAssertFalse(shared.reviewState.permitsAcceptance)
    }

    func testUnsafeFilenamesAndMalformedManifestPoliciesAreRejected() throws {
        for filename in ["../sample.png", "test_snapshot.other.png", "/tmp/sample.png", "sample-ios27-3.png"] {
            XCTAssertThrowsError(try SnapshotReferenceManifest(data: fixtureManifest(
                secondReferences: [logicalFilename: ["filename": filename, "sha256": abcHash]]
            )))
        }
        XCTAssertThrowsError(try SnapshotReferenceManifest(data: fixtureManifest(schemaVersion: 2)))
        XCTAssertThrowsError(try SnapshotReferenceManifest(data: fixtureManifest(
            secondReferences: [logicalFilename: ["filename": logicalFilename, "sha256": "not-a-hash"]]
        )))
        XCTAssertThrowsError(try SnapshotReferenceManifest(data: Data("{broken".utf8)))
    }

    func testDuplicateLiteralAndEscapedPolicyKeysAreRejected() throws {
        let entry = #"{"filename":"test_snapshot.sample.png","sha256":"\#(abcHash)"}"#
        let references = #"{"test_snapshot.sample.png":\#(entry)}"#
        let profile = #"{"reviewState":"reviewed","references":\#(references)}"#
        let documents = [
            #"{"schemaVersion":1,"schemaVersion":2,"runtimes":{"27.0":\#(profile)}}"#,
            #"{"schemaVersion":1,"\u0073chemaVersion":1,"runtimes":{"27.0":\#(profile)}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":\#(profile),"27.0":\#(profile)}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":\#(profile),"27.\u0030":\#(profile)}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":\#(profile),"27.2":{"reviewState":"reviewed","reviewState":"diagnostic","references":\#(references)}}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":\#(profile),"27.2":{"reviewState":"reviewed","\u0072eviewState":"diagnostic","references":\#(references)}}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":{"reviewState":"reviewed","references":{"test_snapshot.sample.png":\#(entry),"test_snapshot.sample.png":\#(entry)}}}}"#,
            #"{"schemaVersion":1,"runtimes":{"27.0":{"reviewState":"reviewed","references":{"test_snapshot.sample.png":{"filename":"test_snapshot.sample.png","filename":"../other.png","sha256":"\#(abcHash)"}}}}}"#
        ]
        for document in documents {
            XCTAssertThrowsError(try SnapshotReferenceManifest(data: Data(document.utf8))) { error in
                guard case let .invalidManifest(reason) = error as? SnapshotReferenceError else {
                    return XCTFail("Expected an explicit duplicate-key rejection, got \(error)")
                }
                XCTAssertTrue(reason.hasPrefix("Duplicate JSON object key:"), reason)
            }
        }
        let valid = #"{"schemaVersion":1,"runtimes":{"27.0":\#(profile)},"metadata":{"example":"{\"reviewState\":\"diagnostic\"}","nested":[{"reviewState":"a"},{"reviewState":"b"}]}}"#
        XCTAssertNoThrow(try SnapshotReferenceManifest(data: Data(valid.utf8)))
    }

    func testRealPublicSnapshotCaptureRestoresTheSelectedWindowFrameAndRoot() throws {
        let saved = try XCTUnwrap(SnapshotWindowRestoration())
        let window = saved.window
        let originalFrame = window.frame
        let originalRoot = try XCTUnwrap(window.rootViewController)
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer {
            saved.restore()
            UIView.setAnimationsEnabled(animationsWereEnabled)
        }
        let captureSize = CGSize(width: 271, height: 319)
        XCTAssertNotEqual(originalFrame.size, captureSize)
        let host = UIViewController()
        host.view.backgroundColor = .systemBlue
        let capture = expectation(description: "The public snapshot strategy captured a real native hierarchy")
        var capturedImage: UIImage?
        Snapshotting<UIViewController, UIImage>.image(
            on: ViewImageConfig(size: captureSize),
            drawHierarchyInKeyWindow: true
        ).snapshot(host).run { image in
            capturedImage = image
            capture.fulfill()
        }
        wait(for: [capture], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(capturedImage).size, captureSize)
        XCTAssertEqual(window.frame.size, captureSize)
        XCTAssertNotIdentical(window.rootViewController, originalRoot)
        saved.restore()
        XCTAssertEqual(window.frame, originalFrame)
        XCTAssertIdentical(window.rootViewController, originalRoot)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func fixtureManifest(
        schemaVersion: Int = 1,
        includesSecondRuntime: Bool = true,
        hasCompleteSecondProfile: Bool = true,
        secondReferences: [String: [String: String]] = [:],
        secondReviewState: String = "diagnostic"
    ) throws -> Data {
        let original = [logicalFilename: ["filename": logicalFilename, "sha256": abcHash]]
        var runtimes: [String: Any] = ["27.0": ["reviewState": "reviewed", "references": original]]
        if includesSecondRuntime {
            let references = hasCompleteSecondProfile ? (secondReferences.isEmpty ? original : secondReferences) : [:]
            runtimes["27.2"] = ["reviewState": secondReviewState, "references": references]
        }
        return try JSONSerialization.data(withJSONObject: ["schemaVersion": schemaVersion, "runtimes": runtimes])
    }
}
