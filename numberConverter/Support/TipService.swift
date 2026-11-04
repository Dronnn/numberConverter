//
//  TipService.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

@MainActor
protocol TipService {
    func loadProducts() async throws -> [TipProduct]
    func purchase(productID: String) async throws -> TipPurchaseResult
    func observeVerifiedTransactions(_ onTransaction: @escaping @MainActor @Sendable (UInt64) async -> Void) async
}

enum TipServiceError: Error {
    case unavailable
    case unexpectedPurchaseResult
}
