import SwiftUI
import Combine
import ServiceManagement
import SystemConfiguration

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
    @AppStorage("NetSpeedUpdateInterval") var netSpeedUpdateInterval: NetSpeedUpdateInterval = .Sec1 {
        didSet { updateNetSpeedUpdateIntervalStatus() }
    }
    @AppStorage("SpeedUnit") var speedUnit: SpeedUnit = .bits {
        didSet { updateSpeedUnitStatus() }
    }
    @Published var menuText = "↑ \(String(format: "%6.2lf", 0)) \(" b")/s\n↓ \(String(format: "%6.2lf", 0)) \(" b")/s"
    
    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(text: menuText)
    }
    
    private var timer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    
    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    private var uploadMetric: String = " b"
    private var downloadMetric: String = " b"
    
    private var speedMetrics: [String] {
        let baseUnit = speedUnit.shortUnit
        return [" \(baseUnit)", "K\(baseUnit)", "M\(baseUnit)", "G\(baseUnit)", "T\(baseUnit)"]
    }
    
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
            logger.info("updateAutoLaunchStatus succeeded, autoLaunchEnabled: \(String(self.autoLaunchEnabled)), service.enabled: \(String(service.status == .enabled))")
        } catch {
            logger.warning("updateAutoLaunchStatus failed: \(error.localizedDescription), autoLaunchEnabled: \(String(self.autoLaunchEnabled)), service.enabled: \(String(service.status == .enabled))")
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
        // Reset metrics to default for new unit
        self.uploadMetric = self.speedMetrics.first!
        self.downloadMetric = self.speedMetrics.first!
    }
    
    private func findPrimaryInterface() -> String? {
        let storeRef = SCDynamicStoreCreate(nil, "FindCurrentInterfaceIpMac" as CFString, nil, nil)
        let global = SCDynamicStoreCopyValue(storeRef, "State:/Network/Global/IPv4" as CFString)
        let primaryInterface = global?.value(forKey: "PrimaryInterface") as? String
        return primaryInterface
    }
    
    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.netSpeedUpdateInterval.rawValue), repeats: true) { _ in

                self.primaryInterface = self.findPrimaryInterface()
                guard let primaryInterface = self.primaryInterface else { return }
                
                let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap()
                if let netTrafficStat = netTrafficStatMap[primaryInterface] {
                    // Apply unit multiplier (8x for bits, 1x for bytes)
                    self.downloadSpeed = netTrafficStat.inboundBytesPerSecond * self.speedUnit.multiplier
                    self.uploadSpeed = netTrafficStat.outboundBytesPerSecond * self.speedUnit.multiplier
                    self.downloadMetric = self.speedMetrics.first!
                    self.uploadMetric = self.speedMetrics.first!
                    for metric in self.speedMetrics.dropFirst() {
                        if self.downloadSpeed > 1000.0 {
                            self.downloadSpeed /= 1024.0
                            self.downloadMetric = metric
                        }
                        if self.uploadSpeed > 1000.0 {
                            self.uploadSpeed /= 1024.0
                            self.uploadMetric = metric
                        }
                    }
                    self.menuText = "↑ \(String(format: "%6.2lf", self.uploadSpeed)) \(self.uploadMetric)/s\n↓ \(String(format: "%6.2lf", self.downloadSpeed)) \(self.downloadMetric)/s"
                    
                    logger.info("deltaIn: \(String(format: "%.6f", self.downloadSpeed)) \(self.downloadMetric)/s, deltaOut: \(String(format: "%.6f", self.uploadSpeed)) \(self.uploadMetric)/s")
                }
            }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
        logger.info("startTimer")
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
        logger.info("stopTimer")
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
        }
    }
}
