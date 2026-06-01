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
/// phase 10 expands event coverage across the screens.
enum AppLogger {
    static let subsystem = "com.mrmaier.NumberConverter"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let converter = Logger(subsystem: subsystem, category: "converter")
    static let allSystems = Logger(subsystem: subsystem, category: "allSystems")
    static let calculator = Logger(subsystem: subsystem, category: "calculator")
    static let quiz = Logger(subsystem: subsystem, category: "quiz")
    static let help = Logger(subsystem: subsystem, category: "help")
}
