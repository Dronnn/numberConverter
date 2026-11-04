//
//  numberConverterApp.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import OSLog
import SwiftUI

@main
struct NumberConverterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var navigation = AppNavigationState()
    @State private var settings = AppSettings()
    @State private var quickActionRouter = QuickActionRouter.shared

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
                .environment(quickActionRouter)
        }
    }
}
