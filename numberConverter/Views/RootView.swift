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

    @State private var tipStore: TipStore

    init(tipStore: TipStore = TipStore.makeAppStore()) {
        _tipStore = State(initialValue: tipStore)
    }

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.tabs) { tab in
                Tab(value: tab) {
                    content(for: tab)
                } label: {
                    Label {
                        Text(tab.titleKey)
                    } icon: {
                        Image(systemName: tab.systemImage)
                    }
                }
                .accessibilityIdentifier("app.tab.\(tab.rawValue)")
            }
        }
        .sheet(isPresented: $navigation.isShowingHelp) {
            HelpIndexView()
        }
        .onChange(of: navigation.selectedTab) { _, newTab in
            AppLogger.lifecycle.info("selected tab \(newTab.rawValue, privacy: .public)")
        }
        // handles cold and warm requests without mutating an observed value inside onchange.
        .task(id: quickActionRouter.requestSequence) { routePendingQuickAction() }
        // safety net: re-check when the scene becomes active.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                routePendingQuickAction()
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .converter:
            NavigationStack { ConverterView() }
        case .allSystems:
            NavigationStack { AllSystemsView() }
        case .calculator:
            NavigationStack { CalculatorView() }
        case .quiz:
            QuizMenuView()
        case .support:
            NavigationStack { SupportView(store: tipStore) }
        case .info:
            EmptyView()
        }
    }

    /// routes a pending home-screen quick action to its tab, then clears it.
    private func routePendingQuickAction() {
        guard let tab = quickActionRouter.pendingTab else { return }
        navigation.select(tabID: tab.rawValue)
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
