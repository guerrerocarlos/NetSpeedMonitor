import Combine
import ServiceManagement
import SwiftUI
import SystemConfiguration
import os.log

enum NetSpeedUpdateInterval: Int, CaseIterable, Identifiable {
    case Sec1 = 1
    case Sec2 = 2
    case Sec5 = 5
    case Sec10 = 10
    case Sec30 = 30

    var id: Int { self.rawValue }

    var displayName: String {
        switch self {
        case .Sec1: return "1s"
        case .Sec2: return "2s"
        case .Sec5: return "5s"
        case .Sec10: return "10s"
        case .Sec30: return "30s"
        }
    }
}

enum SpeedUnit: String, CaseIterable, Identifiable {
    case bits = "bits"
    case bytes = "bytes"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .bits: return "Bits/s"
        case .bytes: return "Bytes/s"
        }
    }

    var multiplier: Double {
        switch self {
        case .bits: return 8.0
        case .bytes: return 1.0
        }
    }

    var shortUnit: String {
        switch self {
        case .bits: return "b"
        case .bytes: return "B"
        }
    }
}

class MenuBarState: ObservableObject {
    @AppStorage("AutoLaunchEnabled") var autoLaunchEnabled: Bool = false {
        didSet { updateAutoLaunchStatus() }
    }
    @AppStorage("NetSpeedUpdateInterval") var netSpeedUpdateInterval: NetSpeedUpdateInterval = .Sec1
    {
        didSet { updateNetSpeedUpdateIntervalStatus() }
    }
    @AppStorage("SpeedUnit") var speedUnit: SpeedUnit = .bits {
        didSet { updateSpeedUnitStatus() }
    }
    @AppStorage("ShowLatencyAndQuality") var showLatencyAndQuality: Bool = true {
        didSet { updateDisplayFormat() }
    }
    @Published var menuText = "--ms  0.0MB/s\n---%  0.0MB/s"

    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(text: menuText)
    }

    private var timer: Timer?
    private var latencyTimer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    private var latencyMeasurer = NetworkLatencyMeasurer()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NetSpeedMonitor",
        category: "MenuBarState")

    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    private var uploadMetric: String = "MB"
    private var downloadMetric: String = "MB"
    private var latencyMs: Double? = nil
    private var latencyHistory: [Double] = []

    private func currentAutoLaunchStatus() -> Bool {
        let service = SMAppService.mainApp
        let status = service.status
        return status == .enabled
    }

    private func updateAutoLaunchStatus() {
        let service = SMAppService.mainApp

        do {
            if autoLaunchEnabled {
                if service.status == .notFound || service.status == .notRegistered {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            logger.info(
                "updateAutoLaunchStatus succeeded, autoLaunchEnabled: \(String(self.autoLaunchEnabled)), service.enabled: \(String(service.status == .enabled))"
            )
        } catch {
            logger.warning(
                "updateAutoLaunchStatus failed: \(error.localizedDescription), autoLaunchEnabled: \(String(self.autoLaunchEnabled)), service.enabled: \(String(service.status == .enabled))"
            )
            autoLaunchEnabled = currentAutoLaunchStatus()
        }
    }

    private func updateNetSpeedUpdateIntervalStatus() {
        logger.info("netSpeedUpdateInterval, \(self.netSpeedUpdateInterval.displayName)")
        self.stopTimer()
        self.startTimer()
    }

    private func updateSpeedUnitStatus() {
        logger.info("speedUnit changed to \(self.speedUnit.displayName)")
        // Always use MB for consistent display
        self.uploadMetric = "MB"
        self.downloadMetric = "MB"
    }

    private func updateDisplayFormat() {
        logger.info("showLatencyAndQuality changed to \(self.showLatencyAndQuality)")
        // Update menu text immediately to reflect the new setting
        self.menuText = self.generateResponsiveMenuText()
    }

    private func getNetworkQuality() -> String {
        guard let currentLatency = latencyMs else { return "---" }

        // Add to history (keep last 5 measurements)
        latencyHistory.append(currentLatency)
        if latencyHistory.count > 5 {
            latencyHistory.removeFirst()
        }

        // Calculate average and variance for stability
        let avgLatency = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        let variance =
            latencyHistory.map { pow($0 - avgLatency, 2) }.reduce(0, +)
            / Double(latencyHistory.count)
        let stability = variance < 100  // Low variance indicates stable connection

        // Calculate quality percentage based on latency and stability
        let baseQuality: Double
        switch avgLatency {
        case 0..<20:
            baseQuality = 95 + (20 - avgLatency) / 20 * 5  // 95-100%
        case 20..<50:
            baseQuality = 80 + (50 - avgLatency) / 30 * 15  // 80-95%
        case 50..<100:
            baseQuality = 50 + (100 - avgLatency) / 50 * 30  // 50-80%
        case 100..<200:
            baseQuality = 20 + (200 - avgLatency) / 100 * 30  // 20-50%
        default:
            baseQuality = max(0, 20 - (avgLatency - 200) / 10)  // 0-20%
        }

        // Adjust for stability (reduce quality if connection is unstable)
        let qualityPercentage = stability ? baseQuality : max(baseQuality - 15, 0)

        return String(format: "%2.0f%%", qualityPercentage)
    }

    private func generateResponsiveMenuText() -> String {
        if showLatencyAndQuality {
            // Show latency and quality with responsive formatting
            let latencyText =
                if let latency = self.latencyMs {
                    String(format: "%.0f", latency) + "ms"
                } else {
                    "--ms"
                }

            let quality = self.getNetworkQuality()

            // Define multiple format levels from most detailed to most compact
            let formats = [
                // Level 1: Full detail
                "\(latencyText) \(String(format: "%5.1f", self.downloadSpeed))MB/s\n\(quality) \(String(format: "%5.1f", self.uploadSpeed))MB/s",

                // Level 2: Medium detail
                "\(latencyText) \(String(format: "%4.1f", self.downloadSpeed))MB\n\(quality) \(String(format: "%4.1f", self.uploadSpeed))MB",

                // Level 3: Compact
                "\(latencyText) \(String(format: "%3.1f", self.downloadSpeed))M\n\(quality) \(String(format: "%3.1f", self.uploadSpeed))M",

                // Level 4: Very compact
                "\(String(format: "%.0f", self.latencyMs ?? 0)) \(String(format: "%3.1f", self.downloadSpeed))\n\(quality) \(String(format: "%3.1f", self.uploadSpeed))",

                // Level 5: Ultra compact (fallback)
                "\(String(format: "%.1f", self.downloadSpeed))\n\(String(format: "%.1f", self.uploadSpeed))",
            ]

            let maxWidth: CGFloat = 85  // Available width in menu bar
            let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)

            // Try each format level until we find one that fits
            for format in formats {
                let textSize = format.size(withAttributes: [.font: font])
                if textSize.width <= maxWidth {
                    return format
                }
            }

            // Return the most compact format as fallback
            return formats.last!
        } else {
            // Simple speed-only format
            return
                "↓ \(String(format: "%5.1f", self.downloadSpeed))MB/s\n↑ \(String(format: "%5.1f", self.uploadSpeed))MB/s"
        }
    }

    private func findPrimaryInterface() -> String? {
        let storeRef = SCDynamicStoreCreate(nil, "FindCurrentInterfaceIpMac" as CFString, nil, nil)
        let global = SCDynamicStoreCopyValue(storeRef, "State:/Network/Global/IPv4" as CFString)
        let primaryInterface = global?.value(forKey: "PrimaryInterface") as? String
        return primaryInterface
    }

    private func startTimer() {
        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(self.netSpeedUpdateInterval.rawValue), repeats: true
        ) { _ in

            self.primaryInterface = self.findPrimaryInterface()
            guard let primaryInterface = self.primaryInterface else {
                self.logger.warning("No primary interface found")
                return
            }

            self.logger.info("Using primary interface: \(primaryInterface)")
            let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap()
            self.logger.info(
                "Found \(netTrafficStatMap.count) interfaces: \(Array(netTrafficStatMap.keys))")

            if let netTrafficStat = netTrafficStatMap[primaryInterface] {
                self.logger.info(
                    "Raw stats - deltaTime: \(netTrafficStat.deltaTime), inbound: \(netTrafficStat.inboundBytesPerSecond) B/s, outbound: \(netTrafficStat.outboundBytesPerSecond) B/s"
                )
                print(
                    "DEBUG: Raw stats - inbound: \(netTrafficStat.inboundBytesPerSecond) B/s, outbound: \(netTrafficStat.outboundBytesPerSecond) B/s"
                )

                // Apply unit multiplier (8x for bits, 1x for bytes)
                self.downloadSpeed =
                    netTrafficStat.inboundBytesPerSecond * self.speedUnit.multiplier
                self.uploadSpeed = netTrafficStat.outboundBytesPerSecond * self.speedUnit.multiplier

                self.logger.info(
                    "After multiplier (\(self.speedUnit.multiplier, privacy: .public)): download=\(self.downloadSpeed, privacy: .public), upload=\(self.uploadSpeed, privacy: .public)"
                )

                // Always convert to MB/s for consistent display
                self.downloadSpeed = self.downloadSpeed / (1024.0 * 1024.0)
                self.uploadSpeed = self.uploadSpeed / (1024.0 * 1024.0)
                self.downloadMetric = "MB"
                self.uploadMetric = "MB"

                // Generate responsive menu text based on available width
                self.menuText = self.generateResponsiveMenuText()

                self.logger.info("Final values: menuText='\(self.menuText, privacy: .public)'")
                self.logger.info(
                    "deltaIn: \(String(format: "%.6f", self.downloadSpeed), privacy: .public) \(self.downloadMetric, privacy: .public)/s, deltaOut: \(String(format: "%.6f", self.uploadSpeed), privacy: .public) \(self.uploadMetric, privacy: .public)/s"
                )
            } else {
                self.logger.warning(
                    "No statistics found for primary interface: \(primaryInterface)")
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
        logger.info("startTimer")

        // Start latency measurement timer (every 10 seconds)
        startLatencyTimer()
    }

    private func startLatencyTimer() {
        stopLatencyTimer()

        let latencyTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.updateLatency()
            }
        }
        RunLoop.current.add(latencyTimer, forMode: .common)
        self.latencyTimer = latencyTimer
        logger.info("startLatencyTimer")

        // Measure latency immediately
        Task {
            await self.updateLatency()
        }
    }

    private func updateLatency() async {
        let latencyStat = await latencyMeasurer.measureLatency()

        await MainActor.run {
            self.latencyMs = latencyStat.latencyMs
            self.logger.info(
                "Latency: \(latencyStat.latencyMs?.description ?? "nil") ms, reachable: \(latencyStat.isReachable)"
            )
        }
    }

    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
        logger.info("stopTimer")
    }

    private func stopLatencyTimer() {
        self.latencyTimer?.invalidate()
        self.latencyTimer = nil
        logger.info("stopLatencyTimer")
    }

    init() {
        DispatchQueue.main.async {
            self.autoLaunchEnabled = self.currentAutoLaunchStatus()
            self.startTimer()
        }
    }

    deinit {
        DispatchQueue.main.async {
            self.stopTimer()
            self.stopLatencyTimer()
        }
    }
}
