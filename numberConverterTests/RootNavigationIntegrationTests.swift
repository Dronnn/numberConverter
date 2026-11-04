//
//  RootNavigationIntegrationTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
@testable import numberConverter
import SwiftUI
import UIKit
import XCTest

@MainActor
final class RootNavigationIntegrationTests: XCTestCase {
    func testPendingQuickActionIsConsumedWhenTheRootAppears() async throws {
        let navigation = AppNavigationState()
        let router = QuickActionRouter()
        router.pendingTab = .calculator

        let mounted = try await mount(navigation: navigation, router: router)
        defer { unmount(mounted) }

        try await waitFor(diagnostics: {
            "expected=calculator, selected=\(navigation.selectedTab.rawValue), pending=\(router.pendingTab?.rawValue ?? "nil")"
        }) {
            navigation.selectedTab == .calculator && router.pendingTab == nil
        }
    }

    func testWarmQuickActionsRouteEveryTabAndClearThePendingRequest() async throws {
        let navigation = AppNavigationState()
        let router = QuickActionRouter()
        let mounted = try await mount(navigation: navigation, router: router)
        defer { unmount(mounted) }

        for tab in AppTab.tabs {
            router.pendingTab = tab
            try await waitFor(diagnostics: {
                "expected=\(tab.rawValue), selected=\(navigation.selectedTab.rawValue), pending=\(router.pendingTab?.rawValue ?? "nil")"
            }) {
                navigation.selectedTab == tab && router.pendingTab == nil
            }
        }
    }

    func testLegacyHelpQuickActionPresentsHelpWithoutReplacingTheCurrentTab() async throws {
        let navigation = AppNavigationState(selectedTab: .calculator)
        let router = QuickActionRouter()
        let mounted = try await mount(navigation: navigation, router: router)
        defer { unmount(mounted) }

        router.pendingTab = .info
        try await waitFor(diagnostics: {
            "selected=\(navigation.selectedTab.rawValue), showing help=\(navigation.isShowingHelp), pending=\(router.pendingTab?.rawValue ?? "nil")"
        }) {
            navigation.isShowingHelp && router.pendingTab == nil
                && mounted.window.rootViewController?.presentedViewController != nil
        }
        XCTAssertEqual(navigation.selectedTab, .calculator)

        navigation.isShowingHelp = false
        try await waitFor {
            mounted.window.rootViewController?.presentedViewController == nil
        }
        XCTAssertEqual(navigation.selectedTab, .calculator)
    }

    func testColdLegacyHelpRequestPreservesTheInitialTool() async throws {
        let navigation = AppNavigationState(selectedTab: .allSystems)
        let router = QuickActionRouter()
        router.pendingTab = .info
        let mounted = try await mount(navigation: navigation, router: router)
        defer { unmount(mounted) }

        try await waitFor {
            navigation.isShowingHelp && router.pendingTab == nil
                && mounted.window.rootViewController?.presentedViewController != nil
        }
        XCTAssertEqual(navigation.selectedTab, .allSystems)
        navigation.isShowingHelp = false
        try await waitFor {
            mounted.window.rootViewController?.presentedViewController == nil
        }
    }

    func testRepeatedRequestsForTheSameTabAreEachConsumed() async throws {
        let navigation = AppNavigationState()
        let router = QuickActionRouter()
        let mounted = try await mount(navigation: navigation, router: router)
        defer { unmount(mounted) }

        for expectedSequence: UInt in 1 ... 5 {
            router.pendingTab = .calculator
            try await waitFor(diagnostics: {
                "expected=calculator, selected=\(navigation.selectedTab.rawValue), pending=\(router.pendingTab?.rawValue ?? "nil"), sequence=\(router.requestSequence)"
            }) {
                navigation.selectedTab == .calculator && router.pendingTab == nil
            }
            XCTAssertEqual(router.requestSequence, expectedSequence)
        }
    }

    private struct MountedRoot {
        let window: UIWindow
        let previousKeyWindow: UIWindow?
        let defaultsSuite: String
    }

    private final class AppearanceTrackingHost<Content: View>: UIHostingController<Content> {
        private(set) var hasAppeared = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }
    }

    private struct NavigationTipService: TipService {
        func loadProducts() async throws -> [TipProduct] {
            []
        }

        func purchase(productID: String) async throws -> TipPurchaseResult {
            .cancelled
        }

        func observeVerifiedTransactions(_: @escaping @MainActor @Sendable (UInt64) async -> Void) async {}
    }

    private func mount(navigation: AppNavigationState, router: QuickActionRouter) async throws -> MountedRoot {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let defaultsSuite = "root-navigation.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defaults.removePersistentDomain(forName: defaultsSuite)

        let root = RootView(tipStore: TipStore(service: NavigationTipService()))
            .environment(navigation)
            .environment(router)
            .environment(AppSettings(defaults: defaults))
        let host = AppearanceTrackingHost(rootView: root)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        try await waitFor(diagnostics: {
            "host appeared=\(host.hasAppeared), key window=\(window.isKeyWindow)"
        }) {
            host.hasAppeared && window.isKeyWindow
        }
        return MountedRoot(window: window, previousKeyWindow: previousKeyWindow, defaultsSuite: defaultsSuite)
    }

    private func unmount(_ mounted: MountedRoot) {
        mounted.window.isHidden = true
        mounted.window.rootViewController = nil
        mounted.previousKeyWindow?.makeKeyAndVisible()
        UserDefaults().removePersistentDomain(forName: mounted.defaultsSuite)
    }

    private func waitFor(
        diagnostics: () -> String = { "" },
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(
            predicate(),
            "The mounted root did not reach the expected state: \(diagnostics())",
            file: file,
            line: line
        )
    }
}
