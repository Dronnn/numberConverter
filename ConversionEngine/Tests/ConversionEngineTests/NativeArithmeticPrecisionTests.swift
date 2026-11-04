//
//  NativeArithmeticPrecisionTests.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import ConversionEngine
import Testing

@Suite struct NativeArithmeticPrecisionTests {
    @Test func exactNativeBoundaryResultsNeverUseSilentlyRoundedDecimalOperations() {
        let maximum = "340282366920938463463374607431768211455" // 2^128 - 1
        let previous = "340282366920938463463374607431768211454"
        let half = "170141183460469231731687303715884105728" // 2^127
        let halfPlusOne = "170141183460469231731687303715884105729"
        let cases: [(ConversionEngine.Operation, String, String, String)] = [
            (.add, half, "1", halfPlusOne),
            (.add, "-" + half, "-1", "-" + halfPlusOne),
            (.subtract, maximum, "1", previous),
            (.subtract, maximum, previous, "1"),
            (.subtract, "-1", half, "-" + halfPlusOne),
            (.add, "-" + maximum, previous, "-1"),
            (.subtract, maximum, maximum, "0"),
            (.multiply, maximum, "1", maximum),
            (.multiply, maximum, "0", "0"),
            // exceeding UInt128 is still allowed when the final native decimal
            // has a trailing zero and therefore a representable coefficient.
            (.add, maximum, "5", "340282366920938463463374607431768211460"),
            (.multiply, maximum, "10", maximum + "0")
        ]
        for (operation, left, right, expected) in cases {
            #expect(ConversionEngine.calculate(operation, left, base: 10, right, base: 10, resultBase: 10) == .success(expected))
        }
        for (operation, left, right) in [
            (ConversionEngine.Operation.add, maximum, "1"),
            (.multiply, half, "2"),
            (.subtract, half, "-" + half)
        ] {
            #expect(ConversionEngine.calculate(operation, left, base: 10, right, base: 10, resultBase: 10) == .failure(.numberOutOfRange))
        }
    }

    @Test func wideProductsMatchIndependentBinaryClosedFormsAcrossRadices() {
        // (2^64-1)^2 = 2^128-2^65+1; the second product is one
        // additional (2^64-1) lower. Constants were independently evaluated.
        let cases: [(UInt64, UInt64, String)] = [
            (.max, .max, "340282366920938463426481119284349108225"),
            (.max, .max - 1, "340282366920938463408034375210639556610"),
            (1 << 63, 2, "18446744073709551616")
        ]
        for base in 2...36 {
            for (left, right, expected) in cases {
                let a = String(left, radix: base, uppercase: true)
                let b = String(right, radix: base, uppercase: true)
                #expect(ConversionEngine.calculate(.multiply, a, base: base, b, base: base, resultBase: 10) == .success(expected))
                #expect(ConversionEngine.calculate(.multiply, "-" + a, base: base, b, base: base, resultBase: 10) == .success("-" + expected))
            }
        }
    }

    @Test func ordinaryIntegerOperationsMatchTheNativeUInt64Oracle() {
        let values: [UInt64] = [0, 1, 2, 9, UInt64(UInt32.max), UInt64(UInt32.max) + 1, UInt64(Int64.max), .max]
        for left in values {
            for right in values {
                for base in [2, 16, 36] {
                    let a = String(left, radix: base, uppercase: true)
                    let b = String(right, radix: 38 - base, uppercase: true)
                    let sum = left.addingReportingOverflow(right)
                    if !sum.overflow {
                        #expect(ConversionEngine.calculate(.add, a, base: base, b, base: 38 - base, resultBase: 10) == .success(String(sum.partialValue)))
                    }
                    let product = left.multipliedReportingOverflow(by: right)
                    if !product.overflow {
                        #expect(ConversionEngine.calculate(.multiply, a, base: base, b, base: 38 - base, resultBase: 10) == .success(String(product.partialValue)))
                    }
                    let difference = left >= right ? String(left - right) : "-" + String(right - left)
                    #expect(ConversionEngine.calculate(.subtract, a, base: base, b, base: 38 - base, resultBase: 10) == .success(difference))
                }
            }
        }
    }
}
