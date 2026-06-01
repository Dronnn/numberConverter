//
//  AppTab.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import SwiftUI

// MARK: - AppTab

/// the five top-level tabs of the app shell.
/// the stable `rawValue` doubles as the routing id used by home-screen
/// quick actions (phase 9) to select a tab programmatically.
enum AppTab: String, CaseIterable, Identifiable {
    case converter
    case allSystems
    case calculator
    case quiz
    case info

    var id: String {
        rawValue
    }

    /// localized tab-bar label.
    var titleKey: LocalizedStringResource {
        switch self {
        case .converter: "tab.converter"
        case .allSystems: "tab.allSystems"
        case .calculator: "tab.calculator"
        case .quiz: "tab.quiz"
        case .info: "tab.info"
        }
    }

    /// localized navigation-bar title for the tab's root screen.
    var navigationTitleKey: LocalizedStringResource {
        switch self {
        case .converter: "nav.converter"
        case .allSystems: "nav.allSystems"
        case .calculator: "nav.calculator"
        case .quiz: "nav.quiz"
        case .info: "nav.info"
        }
    }

    /// sf symbol shown in the tab bar.
    var systemImage: String {
        switch self {
        case .converter: "arrow.left.arrow.right"
        case .allSystems: "square.grid.2x2"
        case .calculator: "plus.forwardslash.minus"
        case .quiz: "checklist"
        case .info: "graduationcap"
        }
    }
}
