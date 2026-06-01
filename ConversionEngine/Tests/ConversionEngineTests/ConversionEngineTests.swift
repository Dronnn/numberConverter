//
//  ConversionEngineTests.swift
//  ConversionEngine
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Testing

// phase-0 scaffold test; phase 1 replaces this with the full golden/correctness suite.
@Suite struct ConversionEngineScaffoldTests {
    @Test func supportedBaseRangeIsTwoToThirtySix() {
        #expect(ConversionEngine.supportedBaseRange == 2...36)
    }
}
