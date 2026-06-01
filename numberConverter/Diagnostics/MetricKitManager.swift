//
//  MetricKitManager.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import MetricKit

// MARK: - MetricKitManager

/// receives apple-native metric and diagnostic (crash) payloads. registering as
/// an `MXMetricManagerSubscriber` delivers both metric payloads (daily) and
/// diagnostic payloads (crashes, hangs, cpu-exceptions, disk-writes), so this is
/// the crash-reporting replacement. payloads are summarized via `os.Logger`.
final class MetricKitManager: NSObject, MXMetricManagerSubscriber {
    func startMonitoring() {
        MXMetricManager.shared.add(self)
    }

    /// summarizes daily metric payloads: a concise line per payload plus the full
    /// json at `.debug` for offline inspection.
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        AppLogger.metrics.info("received \(payloads.count, privacy: .public) metric payload(s)")
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                let count = launch.histogrammedTimeToFirstDraw.totalBucketCount
                AppLogger.metrics.info("launch metric buckets: \(count, privacy: .public)")
            }
            if let responsiveness = payload.applicationResponsivenessMetrics {
                let count = responsiveness.histogrammedApplicationHangTime.totalBucketCount
                AppLogger.metrics.info("hang-time buckets: \(count, privacy: .public)")
            }
            if let memory = payload.memoryMetrics {
                let peak = memory.peakMemoryUsage.description
                AppLogger.metrics.info("peak memory: \(peak, privacy: .public)")
            }
            AppLogger.metrics.debug("metric payload json: \(payload.jsonRepresentation().count) bytes")
        }
    }

    /// summarizes diagnostic payloads (the crashlytics replacement): counts each
    /// diagnostic kind and emits the full json at `.debug`.
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        AppLogger.metrics.info("received \(payloads.count, privacy: .public) diagnostic payload(s)")
        for payload in payloads {
            let crashes = payload.crashDiagnostics?.count ?? 0
            let hangs = payload.hangDiagnostics?.count ?? 0
            let cpuExceptions = payload.cpuExceptionDiagnostics?.count ?? 0
            let diskWrites = payload.diskWriteExceptionDiagnostics?.count ?? 0
            AppLogger.metrics.info(
                """
                diagnostics - crashes: \(crashes, privacy: .public), \
                hangs: \(hangs, privacy: .public), \
                cpu: \(cpuExceptions, privacy: .public), \
                diskWrites: \(diskWrites, privacy: .public)
                """
            )
            AppLogger.metrics.debug("diagnostic payload json: \(payload.jsonRepresentation().count) bytes")
        }
    }
}
