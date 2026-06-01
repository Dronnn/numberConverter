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

    // MARK: - Quick actions (phase 9)

    /// stable home-screen quick-action type string, namespaced under the bundle id.
    /// single source of truth for the shortcut-type ⇄ tab mapping.
    var shortcutType: String {
        "\(AppLogger.subsystem).\(rawValue)"
    }

    /// resolves a home-screen shortcut `type` string back to a tab (`nil` if unknown).
    init?(shortcutType: String) {
        let prefix = "\(AppLogger.subsystem)."
        guard shortcutType.hasPrefix(prefix) else { return nil }
        self.init(rawValue: String(shortcutType.dropFirst(prefix.count)))
    }

    /// home-screen quick-action title.
    /// TODO: localize via String(localized:) once English strings are provided and the RU locale pin is removed.
    /// hardcoded to the exact RU `nav.*` catalog values: the OS resolves shortcut titles
    /// from the bundle, not the SwiftUI `.environment(\.locale)` pin, and the en source is empty.
    var localizedShortcutTitle: String {
        switch self {
        case .converter: "Конвертер систем счисления"
        case .allSystems: "Все системы"
        case .calculator: "Калькулятор"
        case .quiz: "Тестирование"
        case .info: "Справочная информация"
        }
    }
}
