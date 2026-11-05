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
            for (product, expectedPrice) in zip(products, ["2.99", "8.99", "19.99", "49.99", "99.99"]) {
                let nativeProduct = try #require(native.first { $0.id == product.id })
                #expect(nativeProduct.type == .consumable)
                #expect(nativeProduct.price == NSDecimalNumber(string: expectedPrice).decimalValue)
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
            phase("catalog.begin")
            let products = try await service.loadProducts()
            phase("catalog.end")
            let product = try #require(products.first)
            try await verifyRepeatedPurchases(service: service, product: product, probe: probe)
            phase("observer.cancel")
            observer.cancel()
            phase("observer.join.begin")
            await observer.value
            phase("observer.join.end")
        }
    }

    private func verifyRepeatedPurchases(
        service: StoreKitTipService,
        product: TipProduct,
        probe: TipTransactionProbe
    ) async throws {
        var identifiers: Set<UInt64> = []
        for attempt in 0 ..< 2 {
            phase("purchase.\(attempt).begin")
            let result = try await service.purchase(productID: product.id)
            phase("purchase.\(attempt).end result=\(result)")
            guard case let .success(identifier) = result else {
                Issue.record("expected a verified local StoreKit purchase, received \(result)")
                return
            }
            #expect(identifiers.insert(identifier).inserted)
            var unfinished: Set<UInt64> = []
            let finished = await eventuallyAsync {
                unfinished = await unfinishedIdentifiers()
                return !unfinished.contains(identifier)
            }
            phase("finish.assert.begin id=\(identifier) finished=\(finished)")
            #expect(
                finished,
                "transaction \(identifier) unfinished: \(unfinished.sorted()); observed: \(probe.identifiers.sorted())"
            )
            phase("finish.assert.end id=\(identifier)")
        }
        phase("all-finished.assert.begin")
        #expect(await eventuallyAsync {
            let unfinished = await unfinishedIdentifiers()
            return identifiers.isDisjoint(with: unfinished)
        })
        phase("all-finished.assert.end")
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
        let bundle = Bundle(for: StoreKitTipTestBundle.self)
        let url = try #require(bundle.url(forResource: "TipJar", withExtension: "storekit"))
        phase("service.trace.enabled=\(ProcessInfo.processInfo.environment["STOREKIT_TEST_PHASES"] == "1")")
        phase("session.init.begin")
        let session = try SKTestSession(contentsOf: url)
        phase("session.init.end reset.begin")
        session.resetToDefaultState()
        phase("session.reset.end clear.begin")
        session.clearTransactions()
        phase("session.clear.end")
        session.disableDialogs = true
        do {
            try await body(session)
        } catch {
            phase("session.error-cleanup.reset.begin")
            session.resetToDefaultState()
            phase("session.error-cleanup.reset.end clear.begin")
            session.clearTransactions()
            phase("session.error-cleanup.clear.end")
            throw error
        }
        phase("session.cleanup.reset.begin")
        session.resetToDefaultState()
        phase("session.cleanup.reset.end clear.begin")
        session.clearTransactions()
        phase("session.cleanup.clear.end")
    }

    private func unfinishedIdentifiers() async -> Set<UInt64> {
        phase("unfinished.iteration.begin")
        var identifiers: Set<UInt64> = []
        for await result in Transaction.unfinished {
            identifiers.insert(result.unsafePayloadValue.id)
            phase("unfinished.yield id=\(result.unsafePayloadValue.id)")
        }
        phase("unfinished.iteration.end ids=\(identifiers.sorted())")
        return identifiers
    }

    private func phase(_ message: String) {
        FileHandle.standardError.write(Data("STOREKIT_PHASE \(message)\n".utf8))
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

private final class StoreKitTipTestBundle: NSObject {}

@MainActor
private final class TipTransactionProbe {
    var identifiers: Set<UInt64> = []
}
