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
        #expect(AppTab.support.shortcutType == "com.mrmaier.NumberConverter.support")
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
    func requestSequenceChangesForEveryRequestButNotForConsumption() {
        let router = QuickActionRouter()
        #expect(router.requestSequence == 0)
        router.pendingTab = nil
        #expect(router.requestSequence == 0)

        router.pendingTab = .calculator
        #expect(router.requestSequence == 1)
        router.pendingTab = nil
        #expect(router.requestSequence == 1)

        router.pendingTab = .calculator
        #expect(router.requestSequence == 2)
        router.pendingTab = .calculator
        #expect(router.requestSequence == 3)
        router.pendingTab = nil
        #expect(router.requestSequence == 3)
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

    // MARK: - Scene lifecycle delivery

    @Test
    func sceneConfigurationInstallsQuickActionDelegateForApplicationWindows() {
        let configuration = QuickActionSceneDelegate.configuration(for: .windowApplication)

        #expect(configuration.role == .windowApplication)
        #expect(
            configuration.delegateClass.map(ObjectIdentifier.init) == ObjectIdentifier(QuickActionSceneDelegate.self)
        )
    }

    @Test
    func sceneConfigurationLeavesOtherSceneRolesUntouched() {
        let configuration = QuickActionSceneDelegate.configuration(for: .windowExternalDisplayNonInteractive)

        #expect(configuration.role == .windowExternalDisplayNonInteractive)
        #expect(configuration.delegateClass == nil)
    }

    @Test
    func coldSceneActivationRoutesEveryTabOnce() throws {
        let windowScene = try connectedWindowScene()
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }

        for tab in AppTab.allCases {
            let item = UIApplicationShortcutItem(type: tab.shortcutType, localizedTitle: tab.localizedShortcutTitle)
            let delegate = QuickActionSceneDelegate(launchShortcutItem: item)
            let sequence = router.requestSequence

            delegate.sceneDidBecomeActive(windowScene)
            #expect(router.pendingTab == tab)
            #expect(router.requestSequence == sequence &+ 1)

            router.pendingTab = nil
            delegate.sceneDidBecomeActive(windowScene)
            #expect(router.pendingTab == nil)
            #expect(router.requestSequence == sequence &+ 1)
        }
    }

    @Test
    func coldSceneActivationWithoutShortcutLeavesPendingRequestUnchanged() throws {
        let windowScene = try connectedWindowScene()
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }
        router.pendingTab = .quiz
        let sequence = router.requestSequence

        QuickActionSceneDelegate().sceneDidBecomeActive(windowScene)

        #expect(router.pendingTab == .quiz)
        #expect(router.requestSequence == sequence)
    }

    @Test
    func coldSceneActivationRejectsUnknownShortcutWithoutReplay() throws {
        let windowScene = try connectedWindowScene()
        let item = UIApplicationShortcutItem(type: "com.mrmaier.NumberConverter.bogus", localizedTitle: "Bogus")
        let delegate = QuickActionSceneDelegate(launchShortcutItem: item)
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }
        router.pendingTab = .quiz
        let sequence = router.requestSequence

        delegate.sceneDidBecomeActive(windowScene)
        #expect(router.pendingTab == .quiz)
        #expect(router.requestSequence == sequence)

        router.pendingTab = nil
        delegate.sceneDidBecomeActive(windowScene)
        #expect(router.pendingTab == nil)
        #expect(router.requestSequence == sequence)
    }

    @Test
    func warmSceneEntryPointRoutesEveryTabAndCompletesOnce() throws {
        let windowScene = try connectedWindowScene()
        let delegate = QuickActionSceneDelegate()
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }

        for tab in AppTab.allCases {
            let item = UIApplicationShortcutItem(type: tab.shortcutType, localizedTitle: tab.localizedShortcutTitle)
            let sequence = router.requestSequence
            var completions: [Bool] = []

            delegate.windowScene(windowScene, performActionFor: item) { completions.append($0) }

            #expect(router.pendingTab == tab)
            #expect(router.requestSequence == sequence &+ 1)
            #expect(completions == [true])
        }
    }

    @Test
    func warmSceneEntryPointRejectsUnknownShortcut() throws {
        let windowScene = try connectedWindowScene()
        let item = UIApplicationShortcutItem(type: "com.mrmaier.NumberConverter.bogus", localizedTitle: "Bogus")
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }
        router.pendingTab = .quiz
        let sequence = router.requestSequence
        var completions: [Bool] = []

        QuickActionSceneDelegate().windowScene(windowScene, performActionFor: item) { completions.append($0) }

        #expect(router.pendingTab == .quiz)
        #expect(router.requestSequence == sequence)
        #expect(completions == [false])
    }

    @Test
    func warmSceneEntryPointRoutesRepeatedRequests() throws {
        let windowScene = try connectedWindowScene()
        let item = UIApplicationShortcutItem(
            type: AppTab.calculator.shortcutType,
            localizedTitle: AppTab.calculator.localizedShortcutTitle
        )
        let delegate = QuickActionSceneDelegate()
        let router = QuickActionRouter.shared
        defer { router.pendingTab = nil }
        let sequence = router.requestSequence
        var completions: [Bool] = []

        for _ in 0 ..< 2 {
            delegate.windowScene(windowScene, performActionFor: item) { completions.append($0) }
        }

        #expect(router.pendingTab == .calculator)
        #expect(router.requestSequence == sequence &+ 2)
        #expect(completions == [true, true])
    }

    private func connectedWindowScene() throws -> UIWindowScene {
        try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
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
    func registersOnlyTheFourCoreToolQuickActions() {
        let delegate = AppDelegate()
        _ = delegate.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        let shortcuts = UIApplication.shared.shortcutItems ?? []
        #expect(shortcuts.map(\.type) == AppTab.toolTabs.map(\.shortcutType))
        #expect(shortcuts.allSatisfy { !$0.localizedTitle.isEmpty })
        #expect(!shortcuts.contains { $0.type == AppTab.info.shortcutType })
        #expect(!shortcuts.contains { $0.type == AppTab.support.shortcutType })
    }

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
