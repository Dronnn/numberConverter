//
//  StoreKitTipService.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import StoreKit

@MainActor
final class StoreKitTipService: TipService {
    private var catalog: [String: Product] = [:]

    func loadProducts() async throws -> [TipProduct] {
        let fetched = try await Product.products(for: TipProduct.allowedIDs)
        try Task.checkCancellation()
        var available: [String: Product] = [:]
        for product in fetched where product.type == .consumable && TipProduct.allowedIDs.contains(product.id) {
            available[product.id] = product
        }
        catalog = available
        return TipProduct.allowedIDs.compactMap { identifier in
            guard let product = catalog[identifier] else { return nil }
            return TipProduct(id: product.id, displayName: product.displayName, displayPrice: product.displayPrice)
        }
    }

    func purchase(productID: String) async throws -> TipPurchaseResult {
        guard TipProduct.allowedIDs.contains(productID), let product = catalog[productID] else {
            throw TipServiceError.unavailable
        }
        do {
            switch try await product.purchase() {
            case let .success(result):
                guard
                    case let .verified(transaction) = result,
                    transaction.productID == productID, transaction.productType == .consumable,
                    transaction.revocationDate == nil else { return .unverified }
                await transaction.finish()
                return .success(transactionID: transaction.id)
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                throw TipServiceError.unexpectedPurchaseResult
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        }
    }

    func observeVerifiedTransactions(_ onTransaction: @escaping @MainActor @Sendable (UInt64) async -> Void) async {
        async let updates: Void = receive(Transaction.updates, onTransaction: onTransaction)
        await receive(Transaction.unfinished, onTransaction: onTransaction)
        await updates
    }

    private func receive(
        _ transactions: Transaction.Transactions,
        onTransaction: @MainActor @Sendable (UInt64) async -> Void
    ) async {
        for await result in transactions {
            guard !Task.isCancelled else { break }
            guard
                case let .verified(transaction) = result,
                TipProduct.allowedIDs.contains(transaction.productID),
                transaction.productType == .consumable else { continue }
            if transaction.revocationDate == nil {
                await onTransaction(transaction.id)
            }
            await transaction.finish()
        }
    }
}
