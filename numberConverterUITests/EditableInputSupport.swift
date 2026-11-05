//
//  EditableInputSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
struct EditableInputSnapshot {
    let element: XCUIElement
    let frame: CGRect
    let appFrame: CGRect
    let viewport: CGRect
}

@MainActor
extension NumberConverterUITests {
    func visibleEditableInput(_ identifier: String) throws -> EditableInputSnapshot {
        let form = try activeInputForm(identifier)
        for searchBackward in [false, true] {
            for _ in 0 ..< 20 {
                let candidates = editableCandidates(in: form, identifier: identifier)
                let appFrame = app.frame
                let viewport = try inputViewport(form, appFrame: appFrame, identifier: identifier)
                guard candidates.count <= 1 else {
                    return try unsafeInput(identifier, reason: "Multiple typed editors in the active Form")
                }
                guard let field = candidates.first else {
                    // a Form does not instantiate every offscreen row. resolve its
                    // unique active container before scrolling to the real editor.
                    try scrollInputViewport(
                        viewport,
                        appFrame: appFrame,
                        backward: searchBackward,
                        form: form,
                        identifier: identifier
                    )
                    continue
                }
                let frame = field.frame
                let visible = frame.intersection(viewport)
                let center = CGPoint(x: visible.midX, y: visible.midY)
                if
                    finiteInputFrame(frame), field.isHittable,
                    visible.width >= min(44, frame.width), visible.height >= min(44, frame.height),
                    viewport.insetBy(dx: 0, dy: 22).contains(center)
                {
                    return EditableInputSnapshot(element: field, frame: frame, appFrame: appFrame, viewport: viewport)
                }
                attachInputScrollDiagnostics(identifier)
                try scrollInputViewport(
                    viewport,
                    appFrame: appFrame,
                    backward: searchBackward,
                    form: form,
                    identifier: identifier
                )
            }
        }
        return try unsafeInput(identifier, reason: "Editor did not become safely visible after scoped Form scrolling")
    }

    private func attachInputScrollDiagnostics(_ identifier: String) {
        if ProcessInfo.processInfo.environment["UI_FOCUS_DIAGNOSTICS"] == "1" {
            attachInputFocusState(identifier, stage: "before-scoped-scroll")
        }
    }

    func tapEditableInput(_ input: EditableInputSnapshot, identifier: String) throws {
        guard app.state == .runningForeground else {
            return try unsafeInputAction(identifier, reason: "App is not foreground before the input tap")
        }
        let visible = input.frame.intersection(input.viewport)
        let point = CGPoint(x: visible.midX, y: visible.midY)
        guard input.viewport.insetBy(dx: 0, dy: 22).contains(point) else {
            return try unsafeInputAction(identifier, reason: "Observed input point overlaps chrome")
        }
        if ProcessInfo.processInfo.environment["UI_FOCUS_DIAGNOSTICS"] == "1" {
            attachInputFocusState(identifier, stage: "before-observed-tap")
        }
        XCTContext
            .runActivity(named: "Focus \(identifier) at observed content point \(point), editor \(input.frame)") { _ in
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: point.x - input.appFrame.minX,
                    dy: point.y - input.appFrame.minY
                )).tap()
            }
    }

    private func activeInputForm(_ identifier: String) throws -> XCUIElement {
        guard app.state == .runningForeground else {
            return try unsafeInput(identifier, reason: "App is not foreground while resolving the Form")
        }
        for query in [app.collectionViews, app.tables, app.scrollViews] {
            // retain an element from the unfiltered container query. a containing
            // predicate would stop matching when its lazy child scrolls offscreen.
            let forms = query.allElementsBoundByIndex.filter { form in
                guard
                    form.exists, form.frame.intersects(app.frame),
                    form.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists
                else { return false }
                return form
                    .isHittable || (form.textFields.allElementsBoundByIndex + form.textViews.allElementsBoundByIndex)
                    .contains { $0.exists && $0.isHittable }
            }
            if forms.count == 1, let form = forms.first {
                return form
            }
            if forms.count > 1 {
                return try unsafeInput(identifier, reason: "Multiple active Forms contain the editor")
            }
        }
        for query in [app.collectionViews, app.tables, app.scrollViews] {
            let forms = query.allElementsBoundByIndex.filter { form in
                guard form.exists, form.frame.intersects(app.frame) else { return false }
                return (form.textFields.allElementsBoundByIndex + form.textViews.allElementsBoundByIndex)
                    .contains { $0.exists && $0.isHittable }
            }
            if forms.count == 1, let form = forms.first {
                return form
            }
            if forms.count > 1 {
                return try unsafeInput(identifier, reason: "Multiple active Forms while realizing the lazy editor")
            }
        }
        return try unsafeInput(identifier, reason: "No active Form contains the typed editor")
    }

    private func editableCandidates(in form: XCUIElement, identifier: String) -> [XCUIElement] {
        (form.textFields.matching(identifier: identifier).allElementsBoundByIndex
            + form.textViews.matching(identifier: identifier).allElementsBoundByIndex)
            .filter { $0.exists && $0.isEnabled }
    }

    private func inputViewport(_ form: XCUIElement, appFrame: CGRect, identifier: String) throws -> CGRect {
        guard app.state == .runningForeground else {
            return try unsafeInput(identifier, reason: "App left the foreground during input scrolling")
        }
        var viewport = form.frame.intersection(appFrame)
        let bars = app.navigationBars.allElementsBoundByIndex + app.statusBars.allElementsBoundByIndex
            + app.toolbars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
        let topBars = bars.filter { bar in
            guard bar.exists else { return false }
            let frame = bar.frame
            return finiteInputFrame(frame) && frame.intersects(appFrame)
                && frame.midY < appFrame.midY && frame.width > frame.height
        }.map(\.frame)
        let helpButtons = app.buttons.matching(identifier: "app.help").allElementsBoundByIndex
            .filter { $0.exists && finiteInputFrame($0.frame) && $0.frame.intersects(appFrame) }
            .map(\.frame)
        guard let top = topBars.map(\.maxY).max() ?? helpButtons.map(\.maxY).max(), top > appFrame.minY else {
            return try unsafeInput(
                identifier,
                reason: "Present top chrome could not be resolved; refusing a status-bar tap"
            )
        }
        let bottom = app.tabBars.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.intersects(appFrame) && $0.frame.midY > appFrame.midY
                && $0.frame.width > $0.frame.height
        }.map(\.frame.minY).min() ?? viewport.maxY
        viewport = viewport.intersection(CGRect(
            x: appFrame.minX, y: top, width: appFrame.width, height: max(0, bottom - top)
        ))
        guard finiteInputFrame(viewport), viewport.height > 44 else {
            return try unsafeInput(identifier, reason: "The measured content viewport is empty or invalid")
        }
        return viewport
    }

    private func scrollInputViewport(
        _ viewport: CGRect,
        appFrame: CGRect,
        backward: Bool,
        form: XCUIElement,
        identifier: String
    ) throws {
        let route = inputRouteIdentity()
        let originalFrame = form.frame
        let role = form.elementType
        let containerID = form.identifier
        let path = try safeContentDragPath(
            viewport,
            delta: viewport.height * (backward ? -0.5 : 0.5),
            measuredLoss: 0,
            container: form
        )
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(
            dx: path.start.x - appFrame.minX, dy: path.start.y - appFrame.minY
        ))
        let end = origin.withOffset(CGVector(
            dx: path.end.x - appFrame.minX, dy: path.end.y - appFrame.minY
        ))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertEqual(app.frame, appFrame)
        let afterFrame = form.exists ? form.frame : CGRect.null
        let report = XCTAttachment(string: """
        After pan: \(form.exists ? inputFormIdentity(form, identifier: identifier) : "absent")
        Guard before frame: \(inputFrameValues(originalFrame)); after: \(inputFrameValues(afterFrame)).
        Guard role: \(role.rawValue); ID: \(containerID).
        Guard route before: \(route); after: \(inputRouteIdentity()).
        """)
        report.name = "\(identifier)-unfiltered-Form-pan-identity"
        report.lifetime = .keepAlways
        add(report)
        guard
            form.exists, form.elementType == role, form.identifier == containerID,
            sameInputFormFrame(afterFrame, originalFrame), inputRouteIdentity() == route
        else {
            return try unsafeInputAction(
                identifier,
                reason: "The stable Form identity, frame or current route changed after a pan"
            )
        }
    }

    private func inputFrameValues(_ frame: CGRect) -> [Double] {
        [frame.minX, frame.minY, frame.width, frame.height].map(Double.init)
    }

    private func sameInputFormFrame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        guard finiteInputFrame(lhs), finiteInputFrame(rhs) else { return false }
        // native geometry can round either side of the same value while scrolling:
        // 873.9999999999999 and 874.0000000000001 are two representation steps apart.
        return zip(inputFrameValues(lhs), inputFrameValues(rhs)).allSatisfy { old, new in
            old == new || abs(old - new) <= 2 * max(old.ulp, new.ulp)
        }
    }

    private func inputFormIdentity(_ form: XCUIElement, identifier: String) -> String {
        "role=\(form.elementType.rawValue); id=\(form.identifier); frame=\(form.frame); editor currently realized=\(form.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists)"
    }

    private func inputRouteIdentity() -> [String] {
        app.navigationBars.allElementsBoundByIndex.filter { $0.exists && $0.frame.intersects(app.frame) }
            .map(\.identifier).sorted()
    }

    private func finiteInputFrame(_ frame: CGRect) -> Bool {
        frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }

    private func unsafeInput<Value>(_ identifier: String, reason: String) throws -> Value {
        attachInputFocusState(identifier, stage: reason)
        XCTFail("Unsafe input driver geometry: \(identifier): \(reason)")
        throw UIAuditError.missingElement(identifier)
    }

    private func unsafeInputAction(_ identifier: String, reason: String) throws {
        let _: EditableInputSnapshot = try unsafeInput(identifier, reason: reason)
    }

    func attachInputFocusState(_ identifier: String, stage: String) {
        let query = app.descendants(matching: .any).matching(identifier: identifier)
        let matches = query.allElementsBoundByIndex.filter(\.exists).map {
            "type=\($0.elementType); frame=\($0.frame); hittable=\($0.isHittable); value=\(String(describing: $0.value))"
        }
        let report = XCTAttachment(string: """
        Stage: \(stage); app state: \(app.state.rawValue); app frame: \(app.frame).
        All identifier matches: \(matches)
        Full native hierarchy (including Form/window/navigation/status/tab chrome):
        \(app.debugDescription)
        """)
        report.name = "\(identifier)-focus-\(stage)"
        report.lifetime = .keepAlways
        add(report)
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "\(identifier)-focus-\(stage)-screen"
        screen.lifetime = .keepAlways
        add(screen)
    }
}
