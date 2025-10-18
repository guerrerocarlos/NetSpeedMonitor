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
    @Published var menuText =
        "↑ \(String(format: "%6.2lf", 0)) \(" b")/s\n↓ \(String(format: "%6.2lf", 0)) \(" b")/s"

    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(text: menuText)
    }

    private var timer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NetSpeedMonitor",
        category: "MenuBarState")

    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    private var uploadMetric: String = "MB"
    private var downloadMetric: String = "MB"

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
                print("DEBUG: No primary interface found")
                return
            }

            self.logger.info("Using primary interface: \(primaryInterface)")
            print("DEBUG: Using primary interface: \(primaryInterface)")
            let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap()
            self.logger.info(
                "Found \(netTrafficStatMap.count) interfaces: \(Array(netTrafficStatMap.keys))")
            print("DEBUG: Found \(netTrafficStatMap.count) interfaces")

            if let netTrafficStat = netTrafficStatMap[primaryInterface] {
                self.logger.info(
                    "Raw stats - deltaTime: \(netTrafficStat.deltaTime), inbound: \(netTrafficStat.inboundBytesPerSecond) B/s, outbound: \(netTrafficStat.outboundBytesPerSecond) B/s"
                )
                print("DEBUG: Raw stats - inbound: \(netTrafficStat.inboundBytesPerSecond) B/s, outbound: \(netTrafficStat.outboundBytesPerSecond) B/s")

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

                self.menuText =
                    "↑ \(String(format: "%6.2lf", self.uploadSpeed)) \(self.uploadMetric)/s\n↓ \(String(format: "%6.2lf", self.downloadSpeed)) \(self.downloadMetric)/s"

                print("DEBUG: Final calculated speeds - Upload: \(self.uploadSpeed) MB/s, Download: \(self.downloadSpeed) MB/s")
                print("DEBUG: Menu text: '\(self.menuText)'")
                
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
        print("DEBUG: Timer started with interval \(self.netSpeedUpdateInterval.rawValue)s")
    }

    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
        logger.info("stopTimer")
    }

    init() {
        print("DEBUG: MenuBarState init() called")
        DispatchQueue.main.async {
            print("DEBUG: Starting async initialization")
            self.autoLaunchEnabled = self.currentAutoLaunchStatus()
            self.startTimer()
        }
    }

    deinit {
        DispatchQueue.main.async {
            self.stopTimer()
        }
    }
}
