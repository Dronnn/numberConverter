//
//  NativeCatalogTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

@MainActor
extension NumberConverterUITests {
    /// observes the real catalog without requiring server availability or initiating a purchase.
    func testNativeAppStoreCatalogMetadata() throws {
        launch(.english, tipStoreState: nil)
        XCTAssertFalse(app.launchArguments.contains("-ui-tip-store"))
        try selectTab(4)
        let finishedLoading = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element("support.loading")
        )
        XCTAssertEqual(XCTWaiter.wait(for: [finishedLoading], timeout: 45), .completed)
        let identifiers = ["small", "medium", "large", "extraLarge", "patron"].map {
            "com.mrmaier.NumberConverter.tip.\($0)"
        }
        var observed: [String] = []
        for identifier in identifiers {
            let product = element("support.product.\(identifier)")
            guard product.exists else { continue }
            try reveal(product, identifier: "support.product.\(identifier)")
            XCTAssertTrue(product.isEnabled)
            let price = try require("support.price.\(identifier)")
            XCTAssertFalse(price.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            observed.append("\(identifier): \(product.label); price: \(price.label)")
        }
        if observed.isEmpty {
            XCTAssertTrue(try require("support.availability").exists)
            XCTAssertTrue(try require("support.retry").isEnabled)
        }
        let report = XCTAttachment(string: """
        Production StoreKitTipService, no -ui-tip-store argument; no SKTestSession created by this case.
        No purchase buttons selected, no account login or transaction initiated.
        Expected identifiers: \(identifiers)
        Observed products: \(observed)
        Availability UI: \(element("support.availability").exists)
        Actual hierarchy:\n\(app.debugDescription)
        """)
        report.name = "native-app-store-catalog-metadata"
        report.lifetime = .keepAlways
        add(report)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "native-app-store-catalog-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
    }
}
