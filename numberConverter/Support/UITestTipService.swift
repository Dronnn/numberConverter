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
            return zip(TipProduct.allowedIDs, [3, 9, 19, 49, 99]).map { identifier, amount in
                // exact saved App Store Connect Indonesia price for the USD99 tier.
                // this explicit fixture never contacts StoreKit or makes a transaction.
                let price = mode == "regional-price" && amount == 99
                    ? "Rp\u{00A0}1,999,000.00"
                    : formatter.string(from: NSNumber(value: amount)) ?? ""
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
