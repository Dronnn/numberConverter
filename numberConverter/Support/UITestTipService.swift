//
//  UITestTipService.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

#if DEBUG
    import Foundation

    @MainActor
    final class UITestTipService: TipService {
        let mode: String
        let locale: Locale
        private var nextIdentifier: UInt64 = 1
        private var loadCount = 0

        init(mode: String, locale: Locale = .current) {
            self.mode = mode
            self.locale = locale
        }

        func loadProducts() async throws -> [TipProduct] {
            loadCount += 1
            if mode == "unavailable" || (mode == "retry" && loadCount == 1) {
                return []
            }
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            return zip(TipProduct.allowedIDs, [299, 899, 1_999, 4_999, 9_999]).map { identifier, cents in
                let amount = NSDecimalNumber(mantissa: UInt64(cents), exponent: -2, isNegative: false)
                // historical App Store Connect Indonesia price retained as a long-price regression.
                // this explicit fixture never contacts StoreKit or makes a transaction.
                let price = mode == "regional-price" && identifier.hasSuffix(".tip.patron")
                    ? "Rp\u{00A0}1,999,000.00"
                    : formatter.string(from: amount) ?? ""
                return TipProduct(
                    id: identifier,
                    displayName: identifier,
                    displayPrice: price
                )
            }
        }

        func purchase(productID: String) async throws -> TipPurchaseResult {
            switch mode {
            case "pending": return .pending
            case "unverified": return .unverified
            case "failed": throw TipServiceError.unavailable
            case "purchased":
                defer { nextIdentifier += 1 }
                return .success(transactionID: nextIdentifier)
            default: return .cancelled
            }
        }

        func observeVerifiedTransactions(_: @escaping @MainActor @Sendable (UInt64) async -> Void) async {}
    }
#endif
