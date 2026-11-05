//
//  NativeAuditScrollSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
struct NativeAuditScrollAnchor {
    let element: XCUIElement
    let frame: CGRect
    let role: XCUIElement.ElementType
    let label: String
    let identifier: String
}

@MainActor
extension NumberConverterUITests {
    func captureNativeAuditScrollAnchor(
        container: XCUIElement,
        tabBarAffectsViewport: Bool,
        name: String
    ) throws -> NativeAuditScrollAnchor {
        let viewport = try auditRestorationViewport(container, includesTabs: tabBarAffectsViewport, name: name)
        let interactiveFrames = (container.buttons.allElementsBoundByIndex + container.links.allElementsBoundByIndex
            + container.textFields.allElementsBoundByIndex + container.textViews.allElementsBoundByIndex)
            .filter(\.exists).map(\.frame)
        let candidates = container.staticTexts.allElementsBoundByIndex.filter { text in
            guard text.exists, !text.label.isEmpty else { return false }
            let frame = text.frame
            return !frame.isEmpty && viewport.contains(frame)
                && !interactiveFrames.contains { $0.contains(frame) }
        }.sorted { abs($0.frame.midY - viewport.midY) < abs($1.frame.midY - viewport.midY) }
        for candidate in candidates {
            let identifier = candidate.identifier
            let query = identifier.isEmpty
                ? container.staticTexts.matching(NSPredicate(format: "label == %@", candidate.label))
                : container.staticTexts.matching(identifier: identifier)
            guard query.count == 1 else { continue }
            let element = query.element(boundBy: 0)
            let frame = element.frame
            guard viewport.contains(frame) else { continue }
            let anchor = NativeAuditScrollAnchor(
                element: element,
                frame: frame,
                role: element.elementType,
                label: element.label,
                identifier: element.identifier
            )
            attachSelectedAuditAnchor(anchor, name: name)
            return anchor
        }
        let report =
            XCTAttachment(
                string: "No fully visible unique noninteractive text anchor exists in \(viewport). No offscreen interactive control will be used as a restoration ruler."
            )
        report.name = "\(name)-pre-audit-anchor-unavailable"
        report.lifetime = .keepAlways
        add(report)
        XCTFail("No fully visible unique noninteractive anchor can prove the native audit's viewport unchanged")
        throw UIAuditError.missingElement(name)
    }

    private func attachSelectedAuditAnchor(_ anchor: NativeAuditScrollAnchor, name: String) {
        let report =
            XCTAttachment(
                string: "Fully visible unique noninteractive anchor: role=\(anchor.role), id=\(anchor.identifier), frame=\(anchor.frame), label=\(anchor.label)."
            )
        report.name = "\(name)-pre-audit-stable-anchor"
        report.lifetime = .keepAlways
        add(report)
    }

    func restoreAuditScrollPosition(
        container: XCUIElement,
        anchor: NativeAuditScrollAnchor,
        tabBarAffectsViewport: Bool,
        name: String
    ) throws {
        let target = anchor.element
        let previousFrame = anchor.frame
        guard target.exists else {
            attachScrollFailure(name, container: container, target: target)
            throw UIAuditError.missingElement(name)
        }
        guard !auditOffsetIsRestored(
            currentAuditAnchorFrame(anchor),
            previousFrame: previousFrame,
            target: target,
            name: name
        ) else {
            return
        }
        var measuredDragLoss: CGFloat = 0
        for _ in 0 ..< 8 {
            let frame = currentAuditAnchorFrame(anchor)
            if auditOffsetIsRestored(frame, previousFrame: previousFrame, target: target, name: name) {
                attachAuditScrollRestoration(name, frame: frame, previousFrame: previousFrame)
                return
            }
            let viewport = try auditRestorationViewport(container, includesTabs: tabBarAffectsViewport, name: name)
            let distance = try dragAuditViewport(
                viewport,
                delta: frame.minY - previousFrame.minY,
                measuredLoss: measuredDragLoss,
                container: container,
                name: name
            )
            measuredDragLoss = max(0, distance - abs(target.frame.minY - frame.minY))
        }
        let finalFrame = currentAuditAnchorFrame(anchor)
        if auditOffsetIsRestored(finalFrame, previousFrame: previousFrame, target: target, name: name) {
            attachAuditScrollRestoration(name, frame: finalFrame, previousFrame: previousFrame)
            return
        }
        attachScrollFailure(name, container: container, target: target)
        XCTFail("The native audit changed the viewport; its original observed offset could not be restored")
        throw UIAuditError.missingElement(name)
    }

    private func currentAuditAnchorFrame(_ anchor: NativeAuditScrollAnchor) -> CGRect {
        XCTAssertTrue(anchor.element.exists)
        XCTAssertEqual(anchor.element.elementType, anchor.role)
        XCTAssertEqual(anchor.element.label, anchor.label)
        XCTAssertEqual(anchor.element.identifier, anchor.identifier)
        return anchor.element.frame
    }

    private func auditOffsetIsRestored(
        _ frame: CGRect,
        previousFrame: CGRect,
        target: XCUIElement,
        name: String
    ) -> Bool {
        if abs(frame.height - previousFrame.height) > 1 || abs(frame.width - previousFrame.width) > 1 {
            let matches = app.descendants(matching: .any).matching(identifier: target.identifier)
                .allElementsBoundByIndex.filter(\.exists).map { "type=\($0.elementType), frame=\($0.frame)" }
            let report = XCTAttachment(string: """
            Before anchor: \(previousFrame); current captured frame: \(frame).
            Current target: \(target.debugDescription)
            All matching identifier nodes: \(matches)
            Full native hierarchy: \(app.debugDescription)
            """)
            report.name = "\(name)-audit-anchor-geometry-changed"
            report.lifetime = .keepAlways
            add(report)
        }
        XCTAssertEqual(frame.height, previousFrame.height, accuracy: 1)
        XCTAssertEqual(frame.width, previousFrame.width, accuracy: 1)
        return abs(frame.minY - previousFrame.minY) <= 1
    }

    private func auditRestorationViewport(_ container: XCUIElement, includesTabs: Bool, name: String) throws -> CGRect {
        let appFrame = app.frame
        let containerFrame = container.frame.intersection(appFrame)
        let topBars = app.navigationBars.allElementsBoundByIndex + app.statusBars.allElementsBoundByIndex
            + app.toolbars.allElementsBoundByIndex
        let barBottom = topBars.filter { bar in
            guard bar.exists else { return false }
            let frame = bar.frame
            return frame.intersects(appFrame) && frame.width > frame.height && frame.height > 0
                && frame.midY < appFrame.midY
        }.map(\.frame.maxY).max()
        let topControls = app.buttons.matching(identifier: "app.help").allElementsBoundByIndex
            + app.buttons.matching(identifier: "help.close").allElementsBoundByIndex
        let controlBottom = topControls.filter { $0.exists && $0.frame.intersects(appFrame) }
            .map(\.frame.maxY).max()
        guard app.state == .runningForeground, let chromeBottom = barBottom ?? controlBottom else {
            XCTFail("Present top chrome could not be resolved during native audit restoration")
            throw UIAuditError.missingElement(name)
        }
        let top = max(containerFrame.minY, chromeBottom)
        let tabTop = includesTabs
            ? app.tabBars.allElementsBoundByIndex.filter {
                $0.exists && $0.frame.intersects(appFrame) && $0.frame.midY > appFrame.midY
                    && $0.frame.width > $0.frame.height
            }.map(\.frame.minY).min()
            : nil
        let bottom = min(containerFrame.maxY, tabTop ?? containerFrame.maxY)
        let viewport = CGRect(x: containerFrame.minX, y: top, width: containerFrame.width, height: bottom - top)
        guard
            viewport.minX.isFinite, viewport.minY.isFinite, viewport.width.isFinite, viewport.height.isFinite,
            viewport.width > 44, viewport.height > 80, top > appFrame.minY
        else {
            XCTFail("Unsafe content viewport during native audit restoration: \(viewport)")
            throw UIAuditError.missingElement(name)
        }
        return viewport
    }

    private func dragAuditViewport(
        _ viewport: CGRect,
        delta: CGFloat,
        measuredLoss: CGFloat,
        container: XCUIElement,
        name: String
    ) throws -> CGFloat {
        let path = try safeContentDragPath(viewport, delta: delta, measuredLoss: measuredLoss, container: container)
        let appFrame = app.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        XCTContext
            .runActivity(named: "Restore audit viewport from \(path.start) to \(path.end), outside controls") { _ in
                origin.withOffset(CGVector(dx: path.start.x - appFrame.minX, dy: path.start.y - appFrame.minY)).press(
                    forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(
                        dx: path.end.x - appFrame.minX,
                        dy: path.end.y - appFrame.minY
                    )),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.2
                )
            }
        try verifyAuditGestureContext(container, previousAppFrame: appFrame, name: name)
        return abs(path.end.y - path.start.y)
    }

    private func verifyAuditGestureContext(
        _ container: XCUIElement,
        previousAppFrame: CGRect,
        name: String
    ) throws {
        let frame = app.frame
        let closeID = ["help.content", "privacy.content"].contains(container.identifier) ? "help.close" : "app.help"
        let chrome = app.buttons.matching(identifier: closeID).allElementsBoundByIndex.filter {
            $0.exists && $0.isHittable
        }
        guard app.state == .runningForeground, container.exists, frame == previousAppFrame, chrome.count == 1 else {
            let report =
                XCTAttachment(
                    string: "After native drag: state=\(app.state.rawValue), app=\(frame), expected=\(previousAppFrame), container=\(container.debugDescription), visible expected chrome=\(chrome.count)."
                )
            report.name = "\(name)-post-gesture-context-failed"
            report.lifetime = .keepAlways
            add(report)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "\(name)-post-gesture-actual-screen"
            screen.lifetime = .keepAlways
            add(screen)
            XCTFail("Native audit restoration left the original foreground app or screen")
            throw UIAuditError.missingElement(name)
        }
    }

    func scrollObservation(_ container: XCUIElement, target: XCUIElement) -> String {
        let exists = target.exists
        let identifier = exists ? target.identifier : ""
        let matches = identifier.isEmpty
            ? []
            : app.descendants(matching: .any).matching(identifier: identifier)
                .allElementsBoundByIndex.filter(\.exists).map {
                    "type=\($0.elementType), frame=\($0.frame), label=\($0.label)"
                }
        let children = container.children(matching: .any).allElementsBoundByIndex.filter(\.exists)
            .map { "type=\($0.elementType), frame=\($0.frame), id=\($0.identifier)" }
        return "app state=\(app.state.rawValue), app=\(app.frame), container=\(container.frame), "
            + "target exists=\(exists), type=\(exists ? String(describing: target.elementType) : "unavailable"), "
            + "target=\(exists ? String(describing: target.frame) : "unavailable"), all ID matches=\(matches), "
            + "direct scroll content children=\(children)"
    }

    private func attachAuditScrollRestoration(_ name: String, frame: CGRect, previousFrame: CGRect) {
        let report =
            XCTAttachment(
                string: "Restored actual target from native-audit scroll mutation to \(frame); before audit \(previousFrame)."
            )
        report.name = "\(name)-post-audit-restored-geometry"
        report.lifetime = .keepAlways
        add(report)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name)-post-audit-restored-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
