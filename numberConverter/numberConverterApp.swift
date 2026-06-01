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
    @State private var navigation = AppNavigationState()
    @State private var settings = AppSettings()

    private let metricKitManager = MetricKitManager()

    init() {
        AppLogger.lifecycle.info("app launched")
        metricKitManager.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .environment(settings)
        }
    }
}
