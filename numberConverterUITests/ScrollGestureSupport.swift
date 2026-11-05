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
        let controls = interactiveDragFrames(container)
        if let path = sweptDragPath(interior, startY: startY, delta: delta, distance: distance, controls: controls) {
            return path
        }
        if let path = endpointDragPath(interior, startY: startY, delta: delta, distance: distance, controls: controls) {
            attachDragPath(
                "content-pan-observed-safe-endpoints",
                "\(path); viewport: \(viewport); controls: \(controls)"
            )
            return path
        }
        attachDragPath(
            "content-pan-no-safe-endpoints",
            "viewport: \(viewport); distance: \(distance); controls: \(controls)"
        )
        XCTFail("No measured content drag path avoids interactive controls and screen edges")
        throw UIAuditError.missingElement("content drag path")
    }

    private func sweptDragPath(
        _ interior: CGRect, startY: CGFloat, delta: CGFloat, distance: CGFloat, controls: [CGRect]
    ) -> (start: CGPoint, end: CGPoint)? {
        let endY = startY + (delta > 0 ? -distance : distance)
        let band = CGRect(x: interior.minX, y: min(startY, endY), width: interior.width, height: distance)
        let xs = freeDragColumns(interior, controls: controls.filter {
            $0.intersects(band.insetBy(dx: 0, dy: -8))
        })
        for x in xs {
            let start = CGPoint(x: x, y: startY)
            let end = CGPoint(x: x, y: endY)
            let swept = CGRect(x: x - 1, y: band.minY, width: 2, height: distance).insetBy(dx: -8, dy: -8)
            if interior.contains(start), interior.contains(end), !controls.contains(where: { $0.intersects(swept) }) {
                return (start, end)
            }
        }
        return nil
    }

    private func endpointDragPath(
        _ interior: CGRect, startY: CGFloat, delta: CGFloat, distance: CGFloat, controls: [CGRect]
    ) -> (start: CGPoint, end: CGPoint)? {
        // a recognized Form pan may cross a control after starting in content.
        // keep both endpoints outside controls so release cannot activate a Link.
        for (candidateY, endY) in dragEndpointPairs(
            interior, startY: startY, delta: delta, distance: distance, controls: controls
        ) {
            let endpointBands = [candidateY, endY].map {
                CGRect(x: interior.minX, y: $0 - 9, width: interior.width, height: 18)
            }
            let endpointControls = controls.filter { frame in
                endpointBands.contains { $0.intersects(frame) }
            }
            for x in freeDragColumns(interior, controls: endpointControls) {
                let start = CGPoint(x: x, y: candidateY)
                let end = CGPoint(x: x, y: endY)
                guard
                    interior.contains(start), interior.contains(end),
                    !controls.contains(where: { frame in
                        let blocked = frame.insetBy(dx: -9, dy: -9)
                        return blocked.contains(start) || blocked.contains(end)
                    })
                else { continue }
                return (start, end)
            }
        }
        return nil
    }

    private func dragEndpointPairs(
        _ interior: CGRect, startY: CGFloat, delta: CGFloat, distance: CGFloat, controls: [CGRect]
    ) -> [(CGFloat, CGFloat)] {
        let boundaries = controls.flatMap { [$0.minY - 10, $0.maxY + 10] }
        let ys = Array(Set([interior.minY + 1, interior.maxY - 1, startY] + boundaries))
            .filter { $0.isFinite && $0 > interior.minY && $0 < interior.maxY }.sorted()
        return ys.flatMap { first in
            ys.compactMap { last -> (CGFloat, CGFloat)? in
                let movement = delta > 0 ? first - last : last - first
                return movement >= 44 && movement <= distance ? (first, last) : nil
            }
        }.sorted { lhs, rhs in
            let leftDistance = abs(lhs.1 - lhs.0)
            let rightDistance = abs(rhs.1 - rhs.0)
            return leftDistance == rightDistance
                ? abs(lhs.0 - startY) < abs(rhs.0 - startY)
                : leftDistance > rightDistance
        }
    }

    private func attachDragPath(_ name: String, _ description: String) {
        let report = XCTAttachment(string: description)
        report.name = name
        report.lifetime = .keepAlways
        add(report)
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

    private func freeDragColumns(_ interior: CGRect, controls: [CGRect]) -> [CGFloat] {
        var intervals = [(interior.minX, interior.maxX)]
        for frame in controls {
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
