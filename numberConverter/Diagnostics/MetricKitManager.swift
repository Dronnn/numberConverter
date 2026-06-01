//
//  MetricKitManager.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import MetricKit

// MARK: - MetricKitManager

/// receives apple-native metric and diagnostic (crash) payloads.
/// phase 0 just registers the subscriber so data starts flowing;
/// phase 10 handles the payloads.
final class MetricKitManager: NSObject, MXMetricManagerSubscriber {
    func startMonitoring() {
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_: [MXMetricPayload]) {
        // TODO: phase 10 - inspect/persist metric payloads
    }

    nonisolated func didReceive(_: [MXDiagnosticPayload]) {
        // TODO: phase 10 - inspect/persist diagnostic (crash) payloads
    }
}
