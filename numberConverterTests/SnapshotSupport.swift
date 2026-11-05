//
//  SnapshotSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import numberConverter
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

// MARK: - SnapshotDevice

/// compact, standard, landscape and tablet layouts in the screenshot matrix.
enum SnapshotDevice: String, CaseIterable {
    case compact
    case iphone
    case landscape
    case ipad

    /// the `swift-snapshot-testing` layout preset for this device.
    var config: ViewImageConfig {
        switch self {
        case .compact: .iPhoneSe
        case .iphone: .iPhone13
        case .landscape: .iPhone13(.landscape)
        case .ipad: .iPadMini
        }
    }
}

// MARK: - SnapshotAppearance

/// light / dark appearance, contributing the `-light` / `-dark` file suffix.
enum SnapshotAppearance: String, CaseIterable {
    case light
    case dark

    var style: UIUserInterfaceStyle {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - SnapshotLocale

/// the six supported locales rendered by the snapshot matrix.
enum SnapshotLocale: String, CaseIterable {
    case ru
    case en
    case es
    case de
    case fr
    case ptBR = "pt-BR"
}

// MARK: - Matrix helpers

/// the percentage a pixel must match the reference to count as equal. kept
/// below 1.0 so anti-aliasing and sub-pixel text differences are absorbed.
let snapshotPerceptualPrecision: Float = 0.96

// MARK: - MatrixCell

/// one cell of the snapshot matrix: a locale, an appearance and a device.
/// bundled so callers forward a single value instead of three arguments.
struct MatrixCell {
    let locale: SnapshotLocale
    let appearance: SnapshotAppearance
    let device: SnapshotDevice

    /// the file-name suffix this cell contributes: `-<locale>-<light|dark>-<iphone|ipad>`.
    var suffix: String {
        "\(locale.rawValue)-\(appearance.rawValue)-\(device.rawValue)"
    }
}

/// hosts `view` in a `NavigationStack`, applies the environment objects, locale
/// and appearance, and asserts an image snapshot named `<name>-<cell.suffix>`.
@MainActor
func assertScreen(
    _ view: some View,
    named name: String,
    cell: MatrixCell,
    dynamicTypeSize: DynamicTypeSize = .large,
    twosComplement: Bool = false,
    embedsInNavigationStack: Bool = true,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    defer { UIView.setAnimationsEnabled(animationsWereEnabled) }
    let originalWindow = SnapshotWindowRestoration()
    defer { originalWindow?.restore() }
    let settings = AppSettings(defaults: isolatedDefaults())
    settings.twosComplement = twosComplement

    let root = Group {
        if embedsInNavigationStack {
            NavigationStack { view }
        } else {
            view
        }
    }
    .environment(settings)
    .environment(AppNavigationState())
    .environment(QuickActionRouter.shared)
    .environment(\.locale, Locale(identifier: cell.locale.rawValue))
    .environment(\.dynamicTypeSize, dynamicTypeSize)
    .transaction {
        $0.animation = nil
        $0.disablesAnimations = true
    }

    if ProcessInfo.processInfo.environment["SNAPSHOT_LAYER_CLOCK"] != "unpaused" {
        let host = PausedClockHostingController(rootView: root)
        defer { host.restoreLayerClock() }
        if compareScreen(
            host,
            named: "\(name)-\(cell.suffix)",
            cell: cell,
            file: file,
            testName: testName,
            line: line
        ) {
            XCTAssertTrue(host.didPauseClock, "The fixture must pause after a mounted initial render")
        }
    } else {
        let host = UIHostingController(rootView: root)
        compareScreen(host, named: "\(name)-\(cell.suffix)", cell: cell, file: file, testName: testName, line: line)
    }
}

/// matches the dependency's selected window and restores its original frame before its root.
@MainActor
struct SnapshotWindowRestoration {
    let window: UIWindow
    private let frame: CGRect
    private let rootViewController: UIViewController?

    init?() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) else { return nil }
        self.window = window
        frame = window.frame
        rootViewController = window.rootViewController
    }

    func restore() {
        window.frame = frame
        window.rootViewController = rootViewController
    }
}

/// renders the mounted hierarchy once before pausing its public layer clock.
/// hosts are fresh and discarded; this captures their idle appearance, while
/// UI tests exercise interactive behavior with animations running normally.
@MainActor
private final class PausedClockHostingController<Content: View>: UIHostingController<Content> {
    private var originalTiming: (speed: Float, offset: CFTimeInterval, begin: CFTimeInterval)?
    private var isPreparingClock = false

    var didPauseClock: Bool {
        originalTiming != nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.window != nil, !view.bounds.isEmpty, originalTiming == nil, !isPreparingClock else { return }
        isPreparingClock = true
        defer { isPreparingClock = false }
        view.layoutIfNeeded()
        CATransaction.flush()
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: .init(for: traitCollection))
        _ = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        CATransaction.flush()
        let layer = view.layer
        originalTiming = (layer.speed, layer.timeOffset, layer.beginTime)
        let currentTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = currentTime
    }

    func restoreLayerClock() {
        guard let originalTiming else { return }
        view.layer.speed = originalTiming.speed
        view.layer.timeOffset = originalTiming.offset
        view.layer.beginTime = originalTiming.begin
        self.originalTiming = nil
    }
}

@MainActor
@discardableResult
private func compareScreen(
    _ host: UIViewController,
    named name: String,
    cell: MatrixCell,
    file: StaticString,
    testName: String,
    line: UInt
) -> Bool {
    let reference: SnapshotReference
    do {
        reference = try resolvedSnapshotReference(named: name, file: file, testName: testName, line: line)
    } catch {
        XCTFail("Snapshot reference policy failed: \(error)", file: file, line: line)
        return false
    }
    let failure = verifySnapshot(
        of: host,
        as: .image(
            on: cell.device.config,
            drawHierarchyInKeyWindow: true,
            perceptualPrecision: snapshotPerceptualPrecision,
            traits: UITraitCollection(userInterfaceStyle: cell.appearance.style)
        ),
        named: reference.snapshotName,
        record: .never,
        snapshotDirectory: reference.fileURL.deletingLastPathComponent().path,
        file: file,
        testName: testName,
        line: line
    )
    if let failure {
        XCTFail(failure, file: file, line: line)
    }
    return true
}

@MainActor
private func resolvedSnapshotReference(
    named name: String,
    file: StaticString,
    testName: String,
    line: UInt
) throws -> SnapshotReference {
    let usingSourceFixtures = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCE_MODE"] == "source"
    let location = snapshotReferenceLocation(
        sourceFile: "\(file)",
        usingSourceFixtures: usingSourceFixtures
    )
    let manifest = if usingSourceFixtures {
        try SnapshotReferenceManifest(contentsOf: location.manifestURL)
    } else {
        try SnapshotReferenceCatalog.manifest(at: location.manifestURL)
    }
    let runtime = UIDevice.current.systemVersion
    let reference = try manifest.resolve(
        logicalFilename: SnapshotReferenceManifest.logicalFilename(testName: testName, name: name),
        runtime: runtime,
        directory: location.directory
    )
    SnapshotReferenceCatalog.report(
        manifest: manifest,
        runtime: runtime,
        reference: reference,
        testName: testName,
        file: file,
        line: line
    )
    return reference
}

struct SnapshotReferenceLocation {
    let directory: URL
    let manifestURL: URL
}

/// automated comparisons use immutable bundled fixtures, independent of a live checkout.
/// source fixtures require an explicit opt-in and retain the same strict policy.
@MainActor
func snapshotReferenceLocation(sourceFile: String, usingSourceFixtures: Bool = false) -> SnapshotReferenceLocation {
    if usingSourceFixtures {
        let sourceURL = URL(fileURLWithPath: sourceFile)
        let parent = sourceURL.deletingLastPathComponent()
        return SnapshotReferenceLocation(
            directory: parent.appendingPathComponent("__Snapshots__")
                .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent),
            manifestURL: parent.appendingPathComponent("Resources/SnapshotReferences.json")
        )
    }
    let bundle = Bundle(for: SnapshotTests.self)
    let directory = URL(fileURLWithPath: bundle.resourcePath ?? bundle.bundlePath)
    return SnapshotReferenceLocation(
        directory: directory,
        manifestURL: directory.appendingPathComponent("SnapshotReferences.json")
    )
}

@MainActor
private enum SnapshotReferenceCatalog {
    static var manifests: [URL: SnapshotReferenceManifest] = [:]
    static var reportedProfiles: Set<String> = []

    static func manifest(at url: URL) throws -> SnapshotReferenceManifest {
        if let manifest = manifests[url] {
            return manifest
        }
        let manifest = try SnapshotReferenceManifest(contentsOf: url)
        manifests[url] = manifest
        return manifest
    }

    static func report(
        manifest: SnapshotReferenceManifest,
        runtime: String,
        reference: SnapshotReference,
        testName: String,
        file: StaticString,
        line: UInt
    ) {
        if !reference.reviewState.permitsAcceptance {
            XCTFail(
                "The iOS\(runtime) snapshot reference profile is diagnostic and unreviewed; this run cannot pass acceptance",
                file: file,
                line: line
            )
        }
        let identity = "\(testName):\(runtime):\(manifest.sha256)"
        guard reportedProfiles.insert(identity).inserted else { return }
        let state = reference.reviewState.rawValue
        let provenance = "actualRuntime=\(runtime); reviewState=\(state); manifestSHA256=\(manifest.sha256); recording=never"
        print("SNAPSHOT_REFERENCE_POLICY \(provenance)")
        XCTContext.runActivity(named: "Snapshot reference policy: iOS\(runtime), \(state)") { activity in
            let attachment = XCTAttachment(string: provenance)
            attachment.name = "snapshot-reference-policy-\(runtime)-\(state)"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }
}

/// runs `body` for every (locale, appearance, device) cell of the full matrix.
@MainActor
func forEachMatrixCell(_ body: (MatrixCell) -> Void) {
    for locale in SnapshotLocale.allCases {
        for appearance in SnapshotAppearance.allCases {
            for device in SnapshotDevice.allCases {
                autoreleasepool {
                    body(MatrixCell(locale: locale, appearance: appearance, device: device))
                }
            }
        }
    }
}

/// a fresh, isolated UserDefaults suite so snapshots never read or write the
/// real defaults. each call gets a unique, empty domain.
func isolatedDefaults() -> UserDefaults {
    let suiteName = "snapshot.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
