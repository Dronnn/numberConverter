//
//  MetricKitManagerTests.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import Foundation
import MetricKit
@testable import numberConverter
import Testing

@MainActor
struct MetricKitManagerTests {
    @Test
    func metricCallbackProcessesAvailableLaunchHangAndMemoryMeasurements() {
        let payload = MetricPayloadSpy()
        let manager = MetricKitManager()

        manager.didReceive([payload] as [MXMetricPayload])

        #expect(payload.launchReads == 1)
        #expect(payload.hangReads == 1)
        #expect(payload.memoryReads == 1)
        #expect(payload.launch.histogram.readCount == 1)
        #expect(payload.responsiveness.histogram.readCount == 1)
        #expect(payload.memory.readCount == 1)
    }

    @Test
    func metricCallbackAcceptsMissingOptionalMeasurementsAndEmptyDelivery() {
        let manager = MetricKitManager()
        manager.didReceive([] as [MXMetricPayload])
        manager.didReceive([EmptyMetricPayload()] as [MXMetricPayload])
    }

    @Test
    func diagnosticCallbackProcessesAllReportedDiagnosticKinds() {
        let payload = DiagnosticPayloadSpy()
        let manager = MetricKitManager()

        manager.didReceive([payload] as [MXDiagnosticPayload])

        #expect(payload.crashReads == 1)
        #expect(payload.hangReads == 1)
        #expect(payload.cpuReads == 1)
        #expect(payload.diskReads == 1)
    }

    @Test
    func diagnosticCallbackAcceptsMissingDiagnosticsAndEmptyDelivery() {
        let manager = MetricKitManager()
        manager.didReceive([] as [MXDiagnosticPayload])
        manager.didReceive([EmptyDiagnosticPayload()] as [MXDiagnosticPayload])
    }
}

private final class HistogramSpy: MXHistogram<UnitDuration> {
    private(set) var readCount = 0

    override var totalBucketCount: Int {
        readCount += 1
        return 3
    }
}

private final class LaunchMetricSpy: MXAppLaunchMetric {
    let histogram = HistogramSpy()

    override var histogrammedTimeToFirstDraw: MXHistogram<UnitDuration> {
        histogram
    }
}

private final class ResponsivenessMetricSpy: MXAppResponsivenessMetric {
    let histogram = HistogramSpy()

    override var histogrammedApplicationHangTime: MXHistogram<UnitDuration> {
        histogram
    }
}

private final class MemoryMetricSpy: MXMemoryMetric {
    private(set) var readCount = 0

    override var peakMemoryUsage: Measurement<UnitInformationStorage> {
        readCount += 1
        return Measurement(value: 42, unit: .megabytes)
    }
}

private final class MetricPayloadSpy: MXMetricPayload {
    let launch = LaunchMetricSpy()
    let responsiveness = ResponsivenessMetricSpy()
    let memory = MemoryMetricSpy()
    private(set) var launchReads = 0
    private(set) var hangReads = 0
    private(set) var memoryReads = 0

    override var applicationLaunchMetrics: MXAppLaunchMetric? {
        launchReads += 1
        return launch
    }

    override var applicationResponsivenessMetrics: MXAppResponsivenessMetric? {
        hangReads += 1
        return responsiveness
    }

    override var memoryMetrics: MXMemoryMetric? {
        memoryReads += 1
        return memory
    }

    override func jsonRepresentation() -> Data {
        Data("{}".utf8)
    }
}

private final class EmptyMetricPayload: MXMetricPayload {
    override var applicationLaunchMetrics: MXAppLaunchMetric? {
        nil
    }

    override var applicationResponsivenessMetrics: MXAppResponsivenessMetric? {
        nil
    }

    override var memoryMetrics: MXMemoryMetric? {
        nil
    }

    override func jsonRepresentation() -> Data {
        Data("{}".utf8)
    }
}

private final class DiagnosticPayloadSpy: MXDiagnosticPayload {
    private(set) var crashReads = 0
    private(set) var hangReads = 0
    private(set) var cpuReads = 0
    private(set) var diskReads = 0

    override var crashDiagnostics: [MXCrashDiagnostic] {
        crashReads += 1
        return [MXCrashDiagnostic()]
    }

    override var hangDiagnostics: [MXHangDiagnostic] {
        hangReads += 1
        return [MXHangDiagnostic()]
    }

    override var cpuExceptionDiagnostics: [MXCPUExceptionDiagnostic] {
        cpuReads += 1
        return [MXCPUExceptionDiagnostic()]
    }

    override var diskWriteExceptionDiagnostics: [MXDiskWriteExceptionDiagnostic] {
        diskReads += 1
        return [MXDiskWriteExceptionDiagnostic()]
    }

    override func jsonRepresentation() -> Data {
        Data("{}".utf8)
    }
}

private final class EmptyDiagnosticPayload: MXDiagnosticPayload {
    override func jsonRepresentation() -> Data {
        Data("{}".utf8)
    }
}
