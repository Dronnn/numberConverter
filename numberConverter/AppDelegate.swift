//
//  AppDelegate.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import UIKit

// MARK: - AppDelegate

/// registers home-screen quick actions and connects their scene delegate
/// while swiftui continues to create and manage the app's windows.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        // swiftlint:disable:next discouraged_optional_collection
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = AppTab.toolTabs.map { tab in
            UIApplicationShortcutItem(
                type: tab.shortcutType,
                localizedTitle: tab.localizedShortcutTitle,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: tab.systemImage),
                userInfo: nil
            )
        }

        // cold launch: stash the requested tab and return false so the system
        // does not also invoke performActionFor for the same item.
        if
            let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
            let tab = AppTab(shortcutType: item.type)
        {
            QuickActionRouter.shared.pendingTab = tab
            AppLogger.lifecycle.info("cold-launch quick action \(tab.rawValue, privacy: .public)")
            return false
        }

        return true
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        QuickActionSceneDelegate.configuration(for: connectingSceneSession.role)
    }

    func application(
        _: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // legacy lifecycle fallback; scene-based launches use the scene delegate.
        guard let tab = AppTab(shortcutType: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        QuickActionRouter.shared.pendingTab = tab
        AppLogger.lifecycle.info("warm-launch quick action \(tab.rawValue, privacy: .public)")
        completionHandler(true)
    }
}
