//
//  SnapshotTipService.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter

@MainActor
struct SnapshotTipService: TipService {
    let locale: SnapshotLocale
    var mode = "available"

    func loadProducts() async throws -> [TipProduct] {
        guard mode != "unavailable" else { return [] }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale.rawValue)
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
        case "pending": .pending
        case "purchased": .success(transactionID: 1)
        case "unverified": .unverified
        case "failed": throw TipServiceError.unavailable
        default: .cancelled
        }
    }

    func observeVerifiedTransactions(_: @escaping @MainActor @Sendable (UInt64) async -> Void) async {}
}
