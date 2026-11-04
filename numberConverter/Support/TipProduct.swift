//
//  TipProduct.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation

struct TipProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String

    static let allowedIDs = [
        "com.mrmaier.NumberConverter.tip.small",
        "com.mrmaier.NumberConverter.tip.medium",
        "com.mrmaier.NumberConverter.tip.large",
        "com.mrmaier.NumberConverter.tip.extraLarge",
        "com.mrmaier.NumberConverter.tip.patron"
    ]
}

enum TipPurchaseResult: Equatable, Sendable {
    case success(transactionID: UInt64)
    case pending
    case cancelled
    case unverified
}

enum TipStatus: Equatable, Sendable {
    case idle
    case purchased
    case pending
    case unverified
    case unavailable
    case failed
}
