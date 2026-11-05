//
//  QuickActionSceneDelegate.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import UIKit

/// bridges scene-delivered shortcuts into the existing swiftui navigation router.
@MainActor
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    private var launchShortcutItem: UIApplicationShortcutItem?

    override init() {
        super.init()
    }

    init(launchShortcutItem: UIApplicationShortcutItem) {
        self.launchShortcutItem = launchShortcutItem
        super.init()
    }

    static func configuration(for role: UISceneSession.Role) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: role)
        if role == .windowApplication {
            configuration.delegateClass = QuickActionSceneDelegate.self
        }
        return configuration
    }

    func scene(
        _: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        launchShortcutItem = connectionOptions.shortcutItem
    }

    func sceneDidBecomeActive(_: UIScene) {
        guard let item = launchShortcutItem else { return }
        launchShortcutItem = nil
        _ = route(item)
    }

    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(route(shortcutItem))
    }

    private func route(_ item: UIApplicationShortcutItem) -> Bool {
        guard let tab = AppTab(shortcutType: item.type) else { return false }
        QuickActionRouter.shared.pendingTab = tab
        AppLogger.lifecycle.info("scene quick action \(tab.rawValue, privacy: .public)")
        return true
    }
}
