//
//  QuickActionRoutingTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import numberConverter
import Testing

// MARK: - QuickActionRoutingTests

@MainActor
struct QuickActionRoutingTests {
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
}
