//
//  numberConverterUITests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import XCTest

final class NumberConverterUITests: XCTestCase {
    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
    }
}
