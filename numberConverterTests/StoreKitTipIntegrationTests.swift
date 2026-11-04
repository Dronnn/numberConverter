//
//  StoreKitTipIntegrationTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import StoreKit
import StoreKitTest
import Testing

@Suite(.serialized)
@MainActor
struct StoreKitTipIntegrationTests {
    @Test
    func localConsumableCatalogUsesStoreKitPricesAndOrder() async throws {
        try await withSession { _ in
            let service = StoreKitTipService()
            let products = try await service.loadProducts()
            let native = try await Product.products(for: TipProduct.allowedIDs)
            #expect(Set(native.map(\.id)) == Set(TipProduct.allowedIDs))
            #expect(products.map(\.id) == TipProduct.allowedIDs)
            for product in products {
                let nativeProduct = try #require(native.first { $0.id == product.id })
                #expect(nativeProduct.type == .consumable)
                #expect(product.displayPrice == nativeProduct.displayPrice)
                #expect(!product.displayPrice.isEmpty)
            }
        }
    }

    @Test
    func verifiedConsumableTipsCanBePurchasedRepeatedlyAndAreFinished() async throws {
        try await withSession { _ in
            let service = StoreKitTipService()
            let probe = TipTransactionProbe()
            let observer = Task { await service.observeVerifiedTransactions { probe.identifiers.insert($0) } }
            defer { observer.cancel() }
            let products = try await service.loadProducts()
            let product = try #require(products.first)
            var identifiers: Set<UInt64> = []
            for _ in 0 ..< 2 {
                let result = try await service.purchase(productID: product.id)
                guard case let .success(identifier) = result else {
                    Issue.record("expected a verified local StoreKit purchase, received \(result)")
                    return
                }
                #expect(identifiers.insert(identifier).inserted)
                #expect(await eventuallyAsync {
                    let unfinished = await unfinishedIdentifiers()
                    return !unfinished.contains(identifier)
                })
            }
            #expect(await eventuallyAsync {
                let unfinished = await unfinishedIdentifiers()
                return identifiers.isDisjoint(with: unfinished)
            })
            observer.cancel()
            await observer.value
        }
    }

    @Test
    func unknownAndUnloadedProductsCannotStartPurchases() async throws {
        try await withSession { _ in
            let service = StoreKitTipService()
            await #expect(throws: TipServiceError.self) {
                try await service.purchase(productID: TipProduct.allowedIDs[0])
            }
            _ = try await service.loadProducts()
            await #expect(throws: TipServiceError.self) {
                try await service.purchase(productID: "unrelated.product")
            }
        }
    }

    @Test
    func localStoreKitCatalogNetworkFailureCanRecover() async throws {
        try await withSession { session in
            let service = StoreKitTipService()
            try await session.setSimulatedError(
                .generic(.networkError(URLError(.notConnectedToInternet))),
                forAPI: .loadProducts
            )
            await #expect(throws: (any Error).self) { try await service.loadProducts() }
            try await session.setSimulatedError(nil, forAPI: .loadProducts)
            #expect(try await service.loadProducts().count == TipProduct.allowedIDs.count)
        }
    }

    @Test
    func simulatedLocalPurchaseErrorsCannotBeReportedAsSuccessfulTips() async throws {
        try await withSession { session in
            let service = StoreKitTipService()
            let probe = TipTransactionProbe()
            let observer = Task { await service.observeVerifiedTransactions { probe.identifiers.insert($0) } }
            defer { observer.cancel() }
            _ = try await service.loadProducts()
            try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
            do {
                #expect(try await service.purchase(productID: TipProduct.allowedIDs[0]) == .cancelled)
            } catch {
                // this simulator wraps configured cancellation as StoreKitError.unknown;
                // it must remain an error, never be reclassified as a verified tip.
                #expect(error is StoreKitError)
            }
            try await session.setSimulatedError(.purchase(.purchaseNotAllowed), forAPI: .purchase)
            await #expect(throws: (any Error).self) {
                try await service.purchase(productID: TipProduct.allowedIDs[0])
            }
            #expect(probe.identifiers.isEmpty)
            #expect(session.allTransactions().allSatisfy { $0.state != .purchased })
            try await session.setSimulatedError(nil, forAPI: .purchase)
            observer.cancel()
            await observer.value
        }
    }

    @Test
    func pendingAskToBuyApprovalArrivesThroughVerifiedTransactionUpdates() async throws {
        try await withSession { session in
            let service = StoreKitTipService()
            let probe = TipTransactionProbe()
            let observer = Task { await service.observeVerifiedTransactions { probe.identifiers.insert($0) } }
            defer { observer.cancel() }
            _ = try await service.loadProducts()
            session.askToBuyEnabled = true
            #expect(try await service.purchase(productID: TipProduct.allowedIDs[0]) == .pending)
            let pending = try #require(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
            try session.approveAskToBuyTransaction(identifier: pending.identifier)
            #expect(await eventuallyAsync { probe.identifiers.contains(UInt64(pending.identifier)) })
            observer.cancel()
            await observer.value
        }
    }

    @Test
    func unverifiedTransactionsAreNotFinishedOrAcknowledged() async throws {
        try await withSession { session in
            let service = StoreKitTipService()
            let probe = TipTransactionProbe()
            let observer = Task { await service.observeVerifiedTransactions { probe.identifiers.insert($0) } }
            defer { observer.cancel() }
            _ = try await service.loadProducts()
            try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
            #expect(try await service.purchase(productID: TipProduct.allowedIDs[0]) == .unverified)
            let transaction = try #require(session.allTransactions().first)
            #expect(await eventuallyAsync {
                let unfinished = await unfinishedIdentifiers()
                return unfinished.contains(UInt64(transaction.identifier))
            })
            #expect(probe.identifiers.isEmpty)
            observer.cancel()
            await observer.value
            try await session.setSimulatedError(nil, forAPI: .verification)
        }
    }

    @Test
    func verifiedUnfinishedTransactionsAreRecoveredByANewObserver() async throws {
        try await withSession { session in
            // model an interrupted app: StoreKit reports the purchase to a listener,
            // but that listener does not finish it before a new store starts.
            let interruptedListener = Task {
                for await _ in Transaction.updates where Task.isCancelled {
                    break
                }
            }
            defer { interruptedListener.cancel() }
            let transaction = try await session.buyProduct(identifier: TipProduct.allowedIDs[1])
            interruptedListener.cancel()
            await interruptedListener.value
            #expect(await eventuallyAsync {
                let unfinished = await unfinishedIdentifiers()
                return unfinished.contains(transaction.id)
            })
            let service = StoreKitTipService()
            let probe = TipTransactionProbe()
            let observer = Task { await service.observeVerifiedTransactions { probe.identifiers.insert($0) } }
            defer { observer.cancel() }
            #expect(await eventuallyAsync { probe.identifiers.contains(transaction.id) })
            #expect(await eventuallyAsync {
                let unfinished = await unfinishedIdentifiers()
                return !unfinished.contains(transaction.id)
            })
            observer.cancel()
            await observer.value
        }
    }

    private func withSession(_ body: @MainActor (SKTestSession) async throws -> Void) async throws {
        let url = try #require(Bundle.main.url(forResource: "TipJar", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        do {
            try await body(session)
        } catch {
            session.resetToDefaultState()
            session.clearTransactions()
            throw error
        }
        session.resetToDefaultState()
        session.clearTransactions()
    }

    private func unfinishedIdentifiers() async -> Set<UInt64> {
        var identifiers: Set<UInt64> = []
        for await result in Transaction.unfinished {
            identifiers.insert(result.unsafePayloadValue.id)
        }
        return identifiers
    }

    private func eventuallyAsync(_ condition: @MainActor () async -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(8))
        while clock.now < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return await condition()
    }
}

@MainActor
private final class TipTransactionProbe {
    var identifiers: Set<UInt64> = []
}
