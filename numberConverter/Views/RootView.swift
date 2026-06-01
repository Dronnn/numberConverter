//
//  RootView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import OSLog
import SwiftUI

// MARK: - RootView

/// the app shell: a five-tab `TabView` whose selection is driven by the
/// shared `AppNavigationState` so quick actions (phase 9) can route to a tab.
struct RootView: View {
    @Environment(AppNavigationState.self) private var navigation
    @Environment(QuickActionRouter.self) private var quickActionRouter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(value: tab) {
                    NavigationStack {
                        switch tab {
                        case .converter: ConverterView()
                        case .allSystems: AllSystemsView()
                        case .calculator: CalculatorView()
                        case .quiz: QuizMenuView()
                        case .info: HelpIndexView()
                        }
                    }
                } label: {
                    Label {
                        Text(tab.titleKey)
                    } icon: {
                        Image(systemName: tab.systemImage)
                    }
                }
            }
        }
        .onChange(of: navigation.selectedTab) { _, newTab in
            AppLogger.lifecycle.info("selected tab \(newTab.rawValue, privacy: .public)")
        }
        // cold launch: a quick action may already be pending before the view appears.
        .task { routePendingQuickAction() }
        // warm launch: the appdelegate sets a new pending tab while running.
        .onChange(of: quickActionRouter.pendingTab) { _, _ in routePendingQuickAction() }
        // safety net: re-check when the scene becomes active.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { routePendingQuickAction() }
        }
    }

    /// routes a pending home-screen quick action to its tab, then clears it.
    private func routePendingQuickAction() {
        guard let tab = quickActionRouter.pendingTab else { return }
        navigation.selectedTab = tab
        quickActionRouter.pendingTab = nil
        AppLogger.lifecycle.info("routed quick action to \(tab.rawValue, privacy: .public)")
    }
}

#Preview {
    RootView()
        .environment(\.locale, Locale(identifier: "ru"))
        .environment(AppNavigationState())
        .environment(AppSettings())
        .environment(QuickActionRouter.shared)
}
