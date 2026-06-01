//
//  AppNavigationState.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - AppNavigationState

/// shared, observable navigation state for the app shell.
/// `selectedTab` is bindable from `RootView`'s `TabView` and can be set
/// externally so home-screen quick actions (phase 9) can route to a tab.
@Observable
@MainActor
final class AppNavigationState {
    var selectedTab: AppTab

    init(selectedTab: AppTab = .converter) {
        self.selectedTab = selectedTab
    }

    /// selects a tab from its stable routing id (used by quick actions).
    func select(tabID: String) {
        guard let tab = AppTab(rawValue: tabID) else { return }
        selectedTab = tab
    }
}
