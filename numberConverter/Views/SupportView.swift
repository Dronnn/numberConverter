//
//  SupportView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

/// Optional, one-time developer tips. StoreKit supplies every purchasable price.
struct SupportView: View {
    let store: TipStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction
                if showsStatusMessage {
                    statusMessage
                }
                if store.isLoading {
                    ProgressView("support.loading")
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .accessibilityIdentifier("support.loading")
                } else if store.products.isEmpty {
                    unavailable
                } else {
                    tips
                }
            }
            .frame(maxWidth: 560)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("nav.support")
        .navigationBarTitleDisplayMode(.inline)
        .appHelpToolbar()
        .task { await store.loadProducts() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("support.title")
                .font(.title2.bold())
            Text("support.explanation")
                .accessibilityIdentifier("support.explanation")
            Text("support.optional")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("support.tips.header")
                .font(.headline)
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 12) {
                    tipButtons
                        .buttonStyle(.glass)
                }
            } else {
                tipButtons
                    .buttonStyle(.bordered)
            }
            if store.isPurchasing {
                ProgressView("support.purchasing")
                    .accessibilityIdentifier("support.purchasing")
            }
        }
    }

    private var tipButtons: some View {
        VStack(spacing: 12) {
            ForEach(store.products) { product in
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("support.tip")
                            Spacer(minLength: 16)
                            price(for: product)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("support.tip")
                            price(for: product)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("support.product.\(product.id)")
                .disabled(store.isPurchasing)
            }
        }
    }

    private func price(for product: TipProduct) -> some View {
        Text(verbatim: product.displayPrice)
            .fontWeight(.semibold)
            .fixedSize()
            .accessibilityIdentifier("support.price.\(product.id)")
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("support.unavailable.title")
                .font(.headline)
            Text("support.unavailable.message")
                .foregroundStyle(.secondary)
            Button("support.retry") {
                Task { await store.loadProducts() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("support.retry")
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("support.availability")
    }

    private var statusMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusText)
                .fixedSize(horizontal: false, vertical: true)
            Button("support.dismiss") { store.clearStatus() }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("support.status")
    }

    private var showsStatusMessage: Bool {
        switch store.status {
        case .purchased, .pending, .unverified: true
        case .failed: !store.products.isEmpty
        case .idle, .unavailable: false
        }
    }

    private var statusText: LocalizedStringResource {
        switch store.status {
        case .purchased: "support.status.purchased"
        case .pending: "support.status.pending"
        case .unverified: "support.status.unverified"
        case .unavailable: "support.unavailable.message"
        case .failed: "support.status.failed"
        case .idle: "support.optional"
        }
    }
}
