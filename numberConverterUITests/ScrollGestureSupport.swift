//
//  ScrollGestureSupport.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import UIKit
import XCTest

@MainActor
extension NumberConverterUITests {
    func safeContentDragPath(
        _ viewport: CGRect,
        delta: CGFloat,
        measuredLoss: CGFloat,
        container: XCUIElement
    ) throws -> (start: CGPoint, end: CGPoint) {
        let interior = viewport.insetBy(dx: 12, dy: 44)
        let requested = abs(delta) + measuredLoss
        // an adequate overshoot permits an adequate return. a tiny drag can
        // become a tap, even when the requested content correction is small.
        let distance = min(requested < 44 ? 88 : requested, interior.height * 0.55)
        guard distance >= 44 else {
            XCTFail("No adequate interior drag fits the measured content viewport")
            throw UIAuditError.missingElement("content drag viewport")
        }
        let startY = interior.minY + interior.height * (delta > 0 ? 0.75 : 0.25)
        let endY = startY + (delta > 0 ? -distance : distance)
        let controls = interactiveDragFrames(container)
        let band = CGRect(x: interior.minX, y: min(startY, endY), width: interior.width, height: distance)
        let xs = freeDragColumns(interior, sweptBand: band, controls: controls)
        for x in xs {
            let start = CGPoint(x: x, y: startY)
            let end = CGPoint(x: x, y: endY)
            let swept = CGRect(x: x - 1, y: band.minY, width: 2, height: distance).insetBy(dx: -8, dy: -8)
            if interior.contains(start), interior.contains(end), !controls.contains(where: { $0.intersects(swept) }) {
                return (start, end)
            }
        }
        XCTFail("No measured content drag path avoids interactive controls and screen edges")
        throw UIAuditError.missingElement("content drag path")
    }

    private func interactiveDragFrames(_ container: XCUIElement) -> [CGRect] {
        let local = [
            container.buttons,
            container.links,
            container.textFields,
            container.textViews,
            container.switches,
            container.sliders,
            container.segmentedControls
        ]
        .flatMap(\.allElementsBoundByIndex).filter(\.exists)
        let overlays = [app.buttons, app.links, app.textFields, app.textViews, app.switches, app.sliders]
            .flatMap(\.allElementsBoundByIndex).filter { $0.exists && $0.isHittable }
        return (local + overlays).map(\.frame).filter { !$0.isEmpty }
    }

    private func freeDragColumns(_ interior: CGRect, sweptBand: CGRect, controls: [CGRect]) -> [CGFloat] {
        var intervals = [(interior.minX, interior.maxX)]
        for frame in controls where frame.intersects(sweptBand.insetBy(dx: 0, dy: -8)) {
            let blocked = frame.insetBy(dx: -9, dy: -9)
            intervals = intervals.flatMap { left, right -> [(CGFloat, CGFloat)] in
                guard blocked.maxX > left, blocked.minX < right else { return [(left, right)] }
                var remaining: [(CGFloat, CGFloat)] = []
                if blocked.minX > left {
                    remaining.append((left, min(right, blocked.minX)))
                }
                if blocked.maxX < right {
                    remaining.append((max(left, blocked.maxX), right))
                }
                return remaining
            }
        }
        return intervals.filter { $0.1 - $0.0 >= 4 }.sorted { $0.1 - $0.0 > $1.1 - $1.0 }
            .map { ($0.0 + $0.1) / 2 }
    }
}
