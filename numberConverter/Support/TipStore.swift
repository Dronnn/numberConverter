//
//  TipStore.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import Observation

@Observable
@MainActor
final class TipStore {
    private(set) var products: [TipProduct] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var status: TipStatus = .idle

    @ObservationIgnored private let service: any TipService
    @ObservationIgnored private var observer: Task<Void, Never>?
    @ObservationIgnored private var completedTransactions: Set<UInt64> = []

    init(service: any TipService = StoreKitTipService()) {
        self.service = service
        observer = Task { [weak self, service] in
            await service.observeVerifiedTransactions { [weak self] identifier in
                self?.recordVerifiedTransaction(identifier)
            }
        }
    }

    static func makeAppStore() -> TipStore {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-ui-tip-store"), arguments.indices.contains(index + 1) {
                let locale: Locale = if
                    let localeIndex = arguments.firstIndex(of: "-AppleLocale"),
                    arguments.indices.contains(localeIndex + 1)
                {
                    Locale(identifier: arguments[localeIndex + 1])
                } else {
                    .current
                }
                return TipStore(service: UITestTipService(mode: arguments[index + 1], locale: locale))
            }
        #endif
        return TipStore()
    }

    deinit {
        observer?.cancel()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        let completedBeforeLoad = completedTransactions.count
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await service.loadProducts()
            try Task.checkCancellation()
            products = TipProduct.allowedIDs.compactMap { identifier in
                fetched.first { $0.id == identifier && !$0.displayPrice.isEmpty }
            }
            if completedTransactions.count == completedBeforeLoad, !hasPurchaseFeedback {
                if products.isEmpty {
                    status = .unavailable
                } else if status == .unavailable || status == .failed {
                    status = .idle
                }
            }
        } catch is CancellationError {
            return
        } catch {
            products = []
            if completedTransactions.count == completedBeforeLoad, !hasPurchaseFeedback {
                status = .failed
            }
        }
    }

    func purchase(_ product: TipProduct) async {
        guard !isPurchasing else { return }
        guard products.contains(where: { $0.id == product.id }) else {
            status = .unavailable
            return
        }
        isPurchasing = true
        status = .idle
        let completedBeforePurchase = completedTransactions.count
        defer { isPurchasing = false }
        do {
            switch try await service.purchase(productID: product.id) {
            case let .success(identifier):
                recordVerifiedTransaction(identifier)
            case .pending:
                if completedTransactions.count == completedBeforePurchase {
                    status = .pending
                }
            case .cancelled:
                if completedTransactions.count == completedBeforePurchase {
                    status = .idle
                }
            case .unverified:
                if completedTransactions.count == completedBeforePurchase {
                    status = .unverified
                }
            }
        } catch is CancellationError {
            if completedTransactions.count == completedBeforePurchase {
                status = .idle
            }
        } catch {
            if completedTransactions.count == completedBeforePurchase {
                status = .failed
            }
        }
    }

    func clearStatus() {
        status = .idle
    }

    private var hasPurchaseFeedback: Bool {
        status == .purchased || status == .pending || status == .unverified
    }

    private func recordVerifiedTransaction(_ identifier: UInt64) {
        guard completedTransactions.insert(identifier).inserted else { return }
        status = .purchased
    }
}
