//
//  QuickActionRoutingTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import numberConverter
import Testing
import UIKit

// MARK: - QuickActionRoutingTests

@MainActor
struct QuickActionRoutingTests {
    /// resets the shared singleton so it never leaks state between tests.
    init() {
        QuickActionRouter.shared.pendingTab = nil
    }

    // MARK: - Type <-> tab mapping

    @Test
    func shortcutTypeRoundTripsForEveryTab() {
        for tab in AppTab.allCases {
            #expect(AppTab(shortcutType: tab.shortcutType) == tab)
        }
    }

    @Test
    func shortcutTypeUsesBundleNamespace() {
        #expect(AppTab.converter.shortcutType == "com.mrmaier.NumberConverter.converter")
        #expect(AppTab.allSystems.shortcutType == "com.mrmaier.NumberConverter.allSystems")
        #expect(AppTab.calculator.shortcutType == "com.mrmaier.NumberConverter.calculator")
        #expect(AppTab.quiz.shortcutType == "com.mrmaier.NumberConverter.quiz")
        #expect(AppTab.info.shortcutType == "com.mrmaier.NumberConverter.info")
    }

    @Test
    func unknownShortcutTypeResolvesToNil() {
        #expect(AppTab(shortcutType: "com.mrmaier.NumberConverter.bogus") == nil)
        #expect(AppTab(shortcutType: "converter") == nil)
        #expect(AppTab(shortcutType: "") == nil)
        #expect(AppTab(shortcutType: "com.other.app.converter") == nil)
    }

    // MARK: - Navigation routing

    @Test
    func pendingTabDrivesNavigationSelection() {
        let navigation = AppNavigationState()
        #expect(navigation.selectedTab == .converter)

        // simulate the appdelegate stashing a requested tab.
        let router = QuickActionRouter.shared
        router.pendingTab = .calculator

        // mirror RootView's routing step.
        if let tab = router.pendingTab {
            navigation.selectedTab = tab
            router.pendingTab = nil
        }

        #expect(navigation.selectedTab == .calculator)
        #expect(router.pendingTab == nil)
    }

    // MARK: - AppDelegate warm launch (performActionFor)

    @Test
    func warmLaunchRoutesEveryTabAndConfirmsHandling() {
        let delegate = AppDelegate()

        for tab in AppTab.allCases {
            QuickActionRouter.shared.pendingTab = nil

            let item = UIApplicationShortcutItem(
                type: tab.shortcutType,
                localizedTitle: tab.localizedShortcutTitle
            )

            var didHandle = false
            var handled = false
            delegate.application(UIApplication.shared, performActionFor: item) { success in
                didHandle = true
                handled = success
            }

            #expect(QuickActionRouter.shared.pendingTab == tab)
            #expect(didHandle)
            #expect(handled)
        }

        QuickActionRouter.shared.pendingTab = nil
    }

    @Test
    func warmLaunchUnknownShortcutLeavesPendingTabUnchanged() {
        let delegate = AppDelegate()

        // pre-stash a known tab; an unknown shortcut must not overwrite it.
        QuickActionRouter.shared.pendingTab = .quiz

        let item = UIApplicationShortcutItem(
            type: "com.mrmaier.NumberConverter.bogus",
            localizedTitle: "Bogus"
        )

        var didHandle = false
        var handled = true
        delegate.application(UIApplication.shared, performActionFor: item) { success in
            didHandle = true
            handled = success
        }

        #expect(QuickActionRouter.shared.pendingTab == .quiz)
        #expect(didHandle)
        #expect(!handled)

        QuickActionRouter.shared.pendingTab = nil
    }

    // MARK: - AppDelegate cold launch (didFinishLaunchingWithOptions)

    @Test
    func coldLaunchStashesRequestedTabAndDefersSystemHandling() {
        let delegate = AppDelegate()

        for tab in AppTab.allCases {
            QuickActionRouter.shared.pendingTab = nil

            let item = UIApplicationShortcutItem(
                type: tab.shortcutType,
                localizedTitle: tab.localizedShortcutTitle
            )
            let launchOptions: [UIApplication.LaunchOptionsKey: Any] = [.shortcutItem: item]

            let proceed = delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)

            // returns false so the system does not also invoke performActionFor.
            #expect(proceed == false)
            #expect(QuickActionRouter.shared.pendingTab == tab)
        }

        QuickActionRouter.shared.pendingTab = nil
    }

    @Test
    func coldLaunchUnknownShortcutProceedsNormally() {
        let delegate = AppDelegate()

        let item = UIApplicationShortcutItem(
            type: "com.mrmaier.NumberConverter.bogus",
            localizedTitle: "Bogus"
        )
        let launchOptions: [UIApplication.LaunchOptionsKey: Any] = [.shortcutItem: item]

        let proceed = delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)

        #expect(proceed == true)
        #expect(QuickActionRouter.shared.pendingTab == nil)
    }

    @Test
    func normalLaunchProceedsAndLeavesPendingTabNil() {
        let delegate = AppDelegate()

        let proceed = delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        #expect(proceed == true)
        #expect(QuickActionRouter.shared.pendingTab == nil)
    }
}
