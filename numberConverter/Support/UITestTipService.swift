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
        private var nextIdentifier: UInt64 = 1
        private var loadCount = 0

        init(mode: String) {
            self.mode = mode
        }

        func loadProducts() async throws -> [TipProduct] {
            loadCount += 1
            if mode == "unavailable" || (mode == "retry" && loadCount == 1) {
                return []
            }
            let formatter = NumberFormatter()
            formatter.locale = .current
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            return zip(TipProduct.allowedIDs, [3, 9, 19, 49, 99]).map { identifier, amount in
                TipProduct(
                    id: identifier,
                    displayName: identifier,
                    displayPrice: formatter.string(from: NSNumber(value: amount)) ?? ""
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
