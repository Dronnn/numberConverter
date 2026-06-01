//
//  RootView.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

// MARK: - RootView

/// the app shell: a five-tab `TabView` whose selection is driven by the
/// shared `AppNavigationState` so quick actions (phase 9) can route to a tab.
struct RootView: View {
    @Environment(AppNavigationState.self) private var navigation

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
    }
}

#Preview {
    RootView()
        .environment(AppNavigationState())
        .environment(AppSettings())
}
