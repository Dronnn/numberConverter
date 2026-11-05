//
//  TipStoreTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import Testing

@MainActor
struct TipStoreTests {
    private static let small = TipProduct(id: TipProduct.allowedIDs[0], displayName: "Small", displayPrice: "$2.99")
    private static let medium = TipProduct(id: TipProduct.allowedIDs[1], displayName: "Medium", displayPrice: "$8.99")

    @Test
    func initialStateHasNoPurchasableFallbackPrices() {
        let store = TipStore(service: MockTipService())
        #expect(store.products.isEmpty)
        #expect(!store.isLoading)
        #expect(!store.isPurchasing)
        #expect(store.status == .idle)
    }

    @Test
    func catalogIsFilteredDeduplicatedAndOrdered() async {
        let service = MockTipService()
        service.loadedProducts = [
            Self.medium,
            TipProduct(id: "unrelated", displayName: "Other", displayPrice: "$1"),
            Self.small,
            Self.small,
            TipProduct(id: TipProduct.allowedIDs[2], displayName: "No price", displayPrice: "")
        ]
        let store = TipStore(service: service)
        await store.loadProducts()
        #expect(store.products == [Self.small, Self.medium])
        #expect(store.status == .idle)
        #expect(!store.isLoading)
    }

    @Test
    func emptyCatalogAndFailedLoadCanRecover() async {
        let service = MockTipService()
        let store = TipStore(service: service)
        await store.loadProducts()
        #expect(store.status == .unavailable)
        service.loadError = TipTestError.offline
        await store.loadProducts()
        #expect(store.status == .failed)
        #expect(store.products.isEmpty)
        service.loadError = nil
        service.loadedProducts = [Self.small]
        await store.loadProducts()
        #expect(store.products == [Self.small])
        #expect(store.status == .idle)
    }

    @Test
    func concurrentCatalogLoadsCoalesce() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.suspendLoad = true
        let store = TipStore(service: service)
        let loading = Task { await store.loadProducts() }
        #expect(await eventually { service.loadCalls == 1 })
        #expect(store.isLoading)
        await store.loadProducts()
        #expect(service.loadCalls == 1)
        service.resumeLoad()
        await loading.value
        #expect(!store.isLoading)
        #expect(store.products == [Self.small])
    }

    @Test
    func cancelledCatalogLoadLeavesAnIdleRetryableStore() async {
        let service = MockTipService()
        service.loadError = CancellationError()
        let store = TipStore(service: service)
        await store.loadProducts()
        #expect(!store.isLoading)
        #expect(store.status == .idle)
        service.loadError = nil
        service.loadedProducts = [Self.small]
        await store.loadProducts()
        #expect(store.products == [Self.small])
    }

    @Test
    func cancelledTaskCannotPublishAFetchedCatalog() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.suspendLoad = true
        let store = TipStore(service: service)
        let loading = Task { await store.loadProducts() }
        #expect(await eventually { service.loadCalls == 1 })
        loading.cancel()
        service.resumeLoad()
        await loading.value
        #expect(store.products.isEmpty)
        #expect(!store.isLoading)
        #expect(store.status == .idle)
    }

    @Test(arguments: [TipPurchaseResult.pending, .cancelled, .unverified])
    func purchaseOutcomesHaveDistinctStatuses(_ result: TipPurchaseResult) async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = result
        let store = TipStore(service: service)
        await store.loadProducts()
        await store.purchase(Self.small)
        let expected: TipStatus = switch result {
        case .pending: .pending
        case .cancelled: .idle
        case .unverified: .unverified
        case .success: .purchased
        }
        #expect(store.status == expected)
        #expect(!store.isPurchasing)
        #expect(service.purchasedIDs == [Self.small.id])
        store.clearStatus()
        #expect(store.status == .idle)
    }

    @Test
    func purchaseFailureAndCancellationAreRetryable() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseError = TipTestError.offline
        let store = TipStore(service: service)
        await store.loadProducts()
        await store.purchase(Self.small)
        #expect(store.status == .failed)
        #expect(!store.isPurchasing)
        service.purchaseError = CancellationError()
        await store.purchase(Self.small)
        #expect(store.status == .idle)
        service.purchaseError = nil
        service.purchaseResult = .success(transactionID: 42)
        await store.purchase(Self.small)
        #expect(store.status == .purchased)
    }

    @Test
    func catalogMembershipIsRequiredBeforePurchase() async {
        let service = MockTipService()
        let store = TipStore(service: service)
        await store.purchase(Self.small)
        #expect(store.status == .unavailable)
        #expect(service.purchasedIDs.isEmpty)
    }

    @Test
    func concurrentPurchaseTapsProduceOneServiceCall() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.suspendPurchase = true
        service.purchaseResult = .success(transactionID: 12)
        let store = TipStore(service: service)
        await store.loadProducts()
        let purchasing = Task { await store.purchase(Self.small) }
        #expect(await eventually { service.purchasedIDs.count == 1 })
        #expect(store.isPurchasing)
        await store.purchase(Self.small)
        #expect(service.purchasedIDs.count == 1)
        service.resumePurchase()
        await purchasing.value
        #expect(store.status == .purchased)
        #expect(!store.isPurchasing)
    }

    @Test
    func repeatedConsumableTipsRequireUniqueTransactionIdentifiers() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = .success(transactionID: 10)
        let store = TipStore(service: service)
        await store.loadProducts()
        await store.purchase(Self.small)
        #expect(store.status == .purchased)
        store.clearStatus()
        await store.purchase(Self.small)
        #expect(store.status == .idle)
        service.purchaseResult = .success(transactionID: 11)
        await store.purchase(Self.small)
        #expect(store.status == .purchased)
        #expect(service.purchasedIDs.count == 3)
    }

    @Test
    func transactionUpdatesAreDeduplicatedWithPurchaseResults() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        let store = TipStore(service: service)
        #expect(await eventually { service.observerStarted })
        await service.emit(10)
        #expect(store.status == .purchased)
        store.clearStatus()
        await service.emit(10)
        #expect(store.status == .idle)
        await store.loadProducts()
        service.purchaseResult = .success(transactionID: 10)
        await store.purchase(Self.small)
        #expect(store.status == .idle)
        await service.emit(11)
        #expect(store.status == .purchased)
    }

    @Test(arguments: [TipPurchaseResult.pending, .cancelled, .unverified])
    func verifiedUpdateWinsOverAStalePurchaseResult(_ result: TipPurchaseResult) async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.suspendPurchase = true
        service.purchaseResult = result
        let store = TipStore(service: service)
        await store.loadProducts()
        let purchasing = Task { await store.purchase(Self.small) }
        #expect(await eventually { service.purchasedIDs.count == 1 && service.observerStarted })
        await service.emit(22)
        #expect(store.status == .purchased)
        service.resumePurchase()
        await purchasing.value
        #expect(store.status == .purchased)
    }

    @Test(arguments: [false, true])
    func verifiedUpdateWinsOverACatalogFailure(_ throwsError: Bool) async {
        let service = MockTipService()
        service.suspendLoad = true
        if throwsError {
            service.loadError = TipTestError.offline
        }
        let store = TipStore(service: service)
        let loading = Task { await store.loadProducts() }
        #expect(await eventually { service.loadCalls == 1 && service.observerStarted })
        await service.emit(31)
        #expect(store.status == .purchased)
        service.resumeLoad()
        await loading.value
        #expect(store.status == .purchased)
        #expect(store.products.isEmpty)
    }

    @Test(arguments: [TipPurchaseResult.pending, .unverified, .success(transactionID: 52)])
    func reloadingCatalogPreservesExistingPurchaseFeedback(_ result: TipPurchaseResult) async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = result
        let store = TipStore(service: service)
        await store.loadProducts()
        await store.purchase(Self.small)
        let feedback = store.status
        service.loadedProducts = []
        await store.loadProducts()
        #expect(store.status == feedback)
        #expect(store.products.isEmpty)
        service.loadError = TipTestError.offline
        await store.loadProducts()
        #expect(store.status == feedback)
        service.loadError = nil
        service.loadedProducts = [Self.small]
        await store.loadProducts()
        #expect(store.status == feedback)
        #expect(store.products == [Self.small])
        store.clearStatus()
        #expect(store.status == .idle)
    }

    @Test(arguments: [false, true])
    func verifiedUpdateWinsOverAThrownPurchaseError(_ cancellation: Bool) async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.suspendPurchase = true
        service.purchaseError = cancellation ? CancellationError() : TipTestError.offline
        let store = TipStore(service: service)
        await store.loadProducts()
        let purchasing = Task { await store.purchase(Self.small) }
        #expect(await eventually { service.purchasedIDs.count == 1 && service.observerStarted })
        await service.emit(32)
        service.resumePurchase()
        await purchasing.value
        #expect(store.status == .purchased)
        #expect(!store.isPurchasing)
    }

    @Test(arguments: [TipPurchaseResult.pending, .unverified, .success(transactionID: 60)])
    func cancelledCatalogRefreshRetainsAvailablePricesAndPurchaseFeedback(_ result: TipPurchaseResult) async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = result
        let store = TipStore(service: service)
        await store.loadProducts()
        await store.purchase(Self.small)
        let feedback = store.status

        service.loadedProducts = [Self.medium]
        service.suspendLoad = true
        let refreshing = Task { await store.loadProducts() }
        #expect(await eventually { service.loadCalls == 2 && store.isLoading })
        refreshing.cancel()
        service.resumeLoad()
        await refreshing.value

        #expect(store.products == [Self.small])
        #expect(store.status == feedback)
        #expect(!store.isLoading)

        service.suspendLoad = false
        await store.loadProducts()
        #expect(store.products == [Self.medium])
        #expect(store.status == feedback)
    }

    @Test
    func catalogRemovalDoesNotDiscardAnAlreadyStartedVerifiedPurchase() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = .success(transactionID: 61)
        service.suspendPurchase = true
        let store = TipStore(service: service)
        await store.loadProducts()
        let purchasing = Task { await store.purchase(Self.small) }
        #expect(await eventually { service.purchasedIDs == [Self.small.id] && store.isPurchasing })

        service.loadedProducts = []
        await store.loadProducts()
        #expect(store.products.isEmpty)
        #expect(store.isPurchasing)
        await store.purchase(Self.small)
        #expect(service.purchasedIDs == [Self.small.id])

        service.resumePurchase()
        await purchasing.value
        #expect(store.status == .purchased)
        #expect(!store.isPurchasing)

        store.clearStatus()
        await store.purchase(Self.small)
        #expect(store.status == .unavailable)
        #expect(service.purchasedIDs == [Self.small.id])
    }

    @Test
    func replayingAnOlderVerifiedTipDoesNotReplaceANewPendingPurchase() async {
        let service = MockTipService()
        service.loadedProducts = [Self.small]
        service.purchaseResult = .success(transactionID: 62)
        let store = TipStore(service: service)
        #expect(await eventually { service.observerStarted })
        await store.loadProducts()
        await store.purchase(Self.small)
        store.clearStatus()

        service.purchaseResult = .pending
        await store.purchase(Self.small)
        #expect(store.status == .pending)
        await service.emit(62)
        #expect(store.status == .pending)

        await service.emit(63)
        #expect(store.status == .purchased)
    }

    @Test
    func storeLifetimeDoesNotRetainItsTransactionObserver() async {
        let service = MockTipService()
        var store: TipStore? = TipStore(service: service)
        weak let weakStore = store
        #expect(await eventually { service.observerStarted })
        store = nil
        #expect(weakStore == nil)
        #expect(await eventually { service.observerStopped })
    }

    #if DEBUG
        @Test
        func debugCatalogRecoveryAndPurchasesNeverUseStoreKit() async throws {
            let service = UITestTipService(mode: "retry", locale: Locale(identifier: "en_US"))
            #expect(try await service.loadProducts().isEmpty)
            let products = try await service.loadProducts()
            #expect(products.map(\.id) == TipProduct.allowedIDs)
            #expect(products.allSatisfy { !$0.displayPrice.isEmpty })
            #expect(products.map(\.displayPrice) == ["$2.99", "$8.99", "$19.99", "$49.99", "$99.99"])
            let regional = try await UITestTipService(mode: "regional-price").loadProducts()
            let patron = try #require(regional.first { $0.id.hasSuffix(".tip.patron") })
            #expect(patron.displayPrice == "Rp\u{00A0}1,999,000.00")
            #expect(try await service.purchase(productID: Self.small.id) == .cancelled)
            for (mode, expected) in [
                ("pending", TipPurchaseResult.pending),
                ("unverified", .unverified),
                ("purchased", .success(transactionID: 1))
            ] {
                #expect(try await UITestTipService(mode: mode).purchase(productID: Self.small.id) == expected)
            }
            #expect(try await UITestTipService(mode: "unavailable").loadProducts().isEmpty)
            await #expect(throws: TipServiceError.self) {
                try await UITestTipService(mode: "failed").purchase(productID: Self.small.id)
            }
        }
    #endif

    private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0 ..< 1_000 {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }
}

private enum TipTestError: Error {
    case offline
}

@MainActor
private final class MockTipService: TipService {
    var loadedProducts: [TipProduct] = []
    var loadError: (any Error)?
    var purchaseResult: TipPurchaseResult = .cancelled
    var purchaseError: (any Error)?
    var suspendLoad = false
    var suspendPurchase = false
    private(set) var loadCalls = 0
    private(set) var purchasedIDs: [String] = []
    private(set) var observerStarted = false
    private(set) var observerStopped = false
    private var loadContinuation: CheckedContinuation<Void, Never>?
    private var purchaseContinuation: CheckedContinuation<Void, Never>?
    private var observerContinuation: CheckedContinuation<Void, Never>?
    private var callback: (@MainActor @Sendable (UInt64) async -> Void)?

    func loadProducts() async throws -> [TipProduct] {
        loadCalls += 1
        if suspendLoad {
            await withCheckedContinuation { loadContinuation = $0 }
        }
        if let loadError {
            throw loadError
        }
        return loadedProducts
    }

    func purchase(productID: String) async throws -> TipPurchaseResult {
        purchasedIDs.append(productID)
        if suspendPurchase {
            await withCheckedContinuation { purchaseContinuation = $0 }
        }
        if let purchaseError {
            throw purchaseError
        }
        return purchaseResult
    }

    func resumeLoad() {
        let continuation = loadContinuation
        loadContinuation = nil
        continuation?.resume()
    }

    func resumePurchase() {
        let continuation = purchaseContinuation
        purchaseContinuation = nil
        continuation?.resume()
    }

    func emit(_ identifier: UInt64) async {
        await callback?(identifier)
    }

    func observeVerifiedTransactions(_ onTransaction: @escaping @MainActor @Sendable (UInt64) async -> Void) async {
        callback = onTransaction
        observerStarted = true
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume()
                } else {
                    observerContinuation = continuation
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopObserver()
            }
        }
        callback = nil
        observerStopped = true
    }

    private func stopObserver() {
        let continuation = observerContinuation
        observerContinuation = nil
        continuation?.resume()
    }
}
