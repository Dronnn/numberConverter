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
            await settleLayout(in: mounted.window)
            router.pendingTab = tab
            try await waitFor(diagnostics: {
                "expected=\(tab.rawValue), selected=\(navigation.selectedTab.rawValue), "
                    + "pending=\(router.pendingTab?.rawValue ?? "nil"), sequence=\(router.requestSequence), "
                    + self.hostDiagnostics(mounted)
            }) {
                navigation.selectedTab == tab && router.pendingTab == nil
                    && self.nativeTabIsSelected(tab, in: mounted.window)
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
            await settleLayout(in: mounted.window)
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
        let previousRootViewController: UIViewController?
        let defaultsSuite: String
    }

    private final class AppearanceTrackingHost<Content: View>: UIHostingController<Content> {
        private(set) var hasAppeared = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            hasAppeared = false
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
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let previousRootViewController = previousKeyWindow?.rootViewController
        let defaultsSuite = "root-navigation.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defaults.removePersistentDomain(forName: defaultsSuite)

        let root = RootView(tipStore: TipStore(service: NavigationTipService()))
            .environment(navigation)
            .environment(router)
            .environment(AppSettings(defaults: defaults))
            .environment(\.scenePhase, .active)
        let host = AppearanceTrackingHost(rootView: root)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        try await waitFor(diagnostics: {
            "host appeared=\(host.hasAppeared), key window=\(window.isKeyWindow)"
        }) {
            host.hasAppeared && window.isKeyWindow && self.firstTabBarController(in: host) != nil
        }
        return MountedRoot(
            window: window,
            previousKeyWindow: previousKeyWindow,
            previousRootViewController: previousRootViewController,
            defaultsSuite: defaultsSuite
        )
    }

    private func unmount(_ mounted: MountedRoot) {
        mounted.window.endEditing(true)
        mounted.window.isHidden = true
        mounted.window.rootViewController = nil
        mounted.previousKeyWindow?.makeKeyAndVisible()
        if let previousKeyWindow = mounted.previousKeyWindow {
            XCTAssertTrue(previousKeyWindow.isKeyWindow)
            XCTAssertIdentical(previousKeyWindow.rootViewController, mounted.previousRootViewController)
        }
        UserDefaults().removePersistentDomain(forName: mounted.defaultsSuite)
    }

    private func firstTabBarController(in controller: UIViewController) -> UITabBarController? {
        if let tabBar = controller as? UITabBarController {
            return tabBar
        }
        return controller.children.lazy.compactMap { self.firstTabBarController(in: $0) }.first
    }

    private func nativeTabIsSelected(_ tab: AppTab, in window: UIWindow) -> Bool {
        guard
            let root = window.rootViewController,
            let controller = firstTabBarController(in: root),
            let expectedIndex = AppTab.tabs.firstIndex(of: tab) else { return false }
        return controller.selectedIndex == expectedIndex
    }

    private func hostDiagnostics(_ mounted: MountedRoot) -> String {
        let selectedIndex = mounted.window.rootViewController
            .flatMap { self.firstTabBarController(in: $0)?.selectedIndex }
        return "scene=\(String(describing: mounted.window.windowScene?.activationState)), "
            + "key=\(mounted.window.isKeyWindow), attached=\(mounted.window.rootViewController?.view.window != nil), "
            + "nativeTab=\(String(describing: selectedIndex)), appState=\(UIApplication.shared.applicationState.rawValue)"
    }

    private func settleLayout(in window: UIWindow) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                window.layoutIfNeeded()
                DispatchQueue.main.async { continuation.resume() }
            }
        }
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
