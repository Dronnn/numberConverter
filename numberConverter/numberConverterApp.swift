//
//  numberConverterApp.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import OSLog
import SwiftUI

@main
struct NumberConverterApp: App {
    private let metricKitManager = MetricKitManager()

    init() {
        AppLogger.lifecycle.info("app launched")
        metricKitManager.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
