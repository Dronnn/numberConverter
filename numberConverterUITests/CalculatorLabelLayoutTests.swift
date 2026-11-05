//
//  CalculatorLabelLayoutTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    func testRussianCalculatorLabelsRemainRenderedAtNormalAndLargestText() throws {
        try exerciseCalculatorLabels(.russian, expected: "Основание", languages: ["ru-RU"])
    }

    func testFrenchCalculatorLabelsRemainRenderedAtNormalAndLargestText() throws {
        try exerciseCalculatorLabels(.french, expected: "Base de numération", languages: ["fr-FR"])
    }

    func testSpanishAllSystemsLabelsRemainRenderedAtNormalAndLargestText() throws {
        try exerciseBaseRowLabels(
            .spanish,
            tabIndex: 1,
            labels: [
                ("allSystems.sourceBaseLabel", "Base de origen"),
                ("allSystems.targetBaseLabel", "Base de destino")
            ],
            languages: ["es-ES"]
        )
    }

    func testPortugueseAllSystemsLabelsRemainRenderedAtNormalAndLargestText() throws {
        try exerciseBaseRowLabels(
            .portuguese,
            tabIndex: 1,
            labels: [
                ("allSystems.sourceBaseLabel", "Base de origem"),
                ("allSystems.targetBaseLabel", "Base de destino")
            ],
            languages: ["pt-BR"]
        )
    }

    private func exerciseCalculatorLabels(_ language: UITestLanguage, expected: String, languages: [String]) throws {
        let labels = ["baseALabel", "baseBLabel", "resultBaseLabel"].map { ("calculator.\($0)", expected) }
        try exerciseBaseRowLabels(language, tabIndex: 2, labels: labels, languages: languages)
    }

    private func exerciseBaseRowLabels(
        _ language: UITestLanguage,
        tabIndex: Int,
        labels: [(identifier: String, text: String)],
        languages: [String]
    ) throws {
        capturesIncludeNativeAudit = false
        defer { capturesIncludeNativeAudit = true }
        for largeText in [false, true] {
            launch(language, largeText: largeText)
            try selectTab(tabIndex)
            for item in labels {
                let label = element(item.identifier)
                try reveal(label, container: app.collectionViews.firstMatch, identifier: item.identifier)
                try revealWholeBaseLabel(label)
                XCTAssertEqual(label.label, item.text)
                XCTAssertGreaterThanOrEqual(label.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(label.frame.maxX, app.frame.maxX)
                let row = app.cells.containing(.staticText, identifier: item.identifier).firstMatch
                XCTAssertTrue(row.exists)
                XCTAssertTrue(row.frame.contains(label.frame), "The native row must contain the entire label")
                try expectRenderedText(
                    label,
                    expected: item.text,
                    name: "\(language.rawValue)-\(item.identifier)-\(largeText ? "AX5" : "normal")",
                    recognitionLanguages: languages
                )
            }
            app.terminate()
        }
    }

    private func revealWholeBaseLabel(_ label: XCUIElement) throws {
        let form = app.collectionViews.firstMatch
        for _ in 0 ..< 30 {
            let viewport = form.frame.intersection(app.frame)
            let top = app.navigationBars.allElementsBoundByIndex
                .filter { $0.isHittable && $0.frame.intersects(label.frame) }
                .map(\.frame.maxY).max() ?? viewport.minY
            let bottom = app.tabBars.firstMatch.exists
                ? min(viewport.maxY, app.tabBars.firstMatch.frame.minY)
                : viewport.maxY
            if label.frame.minY >= top, label.frame.maxY <= bottom {
                XCTAssertTrue(label.isHittable)
                return
            }
            if label.frame.maxY > bottom {
                form.swipeUp(velocity: .slow)
            } else {
                form.swipeDown(velocity: .slow)
            }
        }
        XCTFail("The entire base label must be visible before measuring its glyphs")
        throw UIAuditError.missingElement("base.label.viewport")
    }
}
