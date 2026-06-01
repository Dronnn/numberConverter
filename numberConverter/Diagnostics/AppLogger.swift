//
//  AppLogger.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog

// MARK: - AppLogger

/// centralized os.Logger categories (apple-native diagnostics).
/// phase 10 expands event coverage across the screens. it is `nonisolated` so
/// the metrickit delegate callbacks (which arrive off the main actor) can log
/// alongside the `@MainActor` screens and view models.
nonisolated enum AppLogger {
    static let subsystem = "com.mrmaier.NumberConverter"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let converter = Logger(subsystem: subsystem, category: "converter")
    static let allSystems = Logger(subsystem: subsystem, category: "allSystems")
    static let calculator = Logger(subsystem: subsystem, category: "calculator")
    static let quiz = Logger(subsystem: subsystem, category: "quiz")
    static let help = Logger(subsystem: subsystem, category: "help")
    static let metrics = Logger(subsystem: subsystem, category: "metrics")
}

// MARK: - Logger + Screen

extension Logger {
    /// logs a screen appearance with a stable, public descriptor so user flow
    /// is readable in Console. the name is a static literal (never user input).
    func screen(_ name: StaticString) {
        info("screen: \(name, privacy: .public)")
    }
}
