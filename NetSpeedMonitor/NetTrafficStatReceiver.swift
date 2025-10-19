import Darwin
import Foundation
import os.log

struct NetTrafficStat {
    let timestamp: Date
    let deltaTime: TimeInterval
    let deltaInboundBytes: UInt64
    let deltaOutboundBytes: UInt64
    let inboundBytesPerSecond: Double
    let outboundBytesPerSecond: Double
}

final class NetTrafficStatReceiver {
    private struct InterfaceSnapshot {
        var timestamp: Date
        var inboundBytes: UInt64
        var outboundBytes: UInt64
    }

    private var snapshots: [String: InterfaceSnapshot] = [:]
    private var sysctlBuffer = Data()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "NetSpeedMonitor",
        category: "NetTrafficStatReceiver")

    func reset() {
        snapshots.removeAll()
        sysctlBuffer.removeAll(keepingCapacity: false)
    }

    func getNetTrafficStatMap() -> [String: NetTrafficStat] {
        print("DEBUG: NetTrafficStatReceiver.getNetTrafficStatMap() called")
        do {
            let stats = try fetchStats()
            print("DEBUG: fetchStats() returned \(stats.count) interfaces")
            logger.info("Found \(stats.count, privacy: .public) interfaces with stats")
            for (interface, stat) in stats {
                logger.info(
                    "Interface \(interface, privacy: .public): inbound: \(stat.inboundBytesPerSecond, privacy: .public) B/s, outbound: \(stat.outboundBytesPerSecond, privacy: .public) B/s"
                )
            }
            return stats
        } catch {
            print("DEBUG: fetchStats() threw error: \(error)")
            logger.warning(
                "Failed to fetch network statistics: \(error.localizedDescription, privacy: .public)"
            )
            return [:]
        }
    }

    private func fetchStats() throws -> [String: NetTrafficStat] {
        print("DEBUG: fetchStats() starting")
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0]
        var length = 0

        let status = mib.withUnsafeMutableBufferPointer { pointer -> Int32 in
            guard let baseAddress = pointer.baseAddress else { return -1 }
            return sysctl(baseAddress, u_int(pointer.count), nil, &length, nil, 0)
        }

        guard status == 0 else {
            print("DEBUG: sysctl query failed with status \(status), errno: \(errno)")
            throw SysctlError.unableToQuery(errno: errno)
        }

        print("DEBUG: sysctl query successful, length: \(length)")

        if sysctlBuffer.count < length {
            sysctlBuffer = Data(count: length)
        }

        var dataLength = length
        let fetchStatus = sysctlBuffer.withUnsafeMutableBytes { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return mib.withUnsafeMutableBufferPointer { pointer -> Int32 in
                guard let mibBase = pointer.baseAddress else { return -1 }
                return sysctl(mibBase, u_int(pointer.count), baseAddress, &dataLength, nil, 0)
            }
        }

        guard fetchStatus == 0 else {
            print("DEBUG: sysctl fetch failed with status \(fetchStatus), errno: \(errno)")
            throw SysctlError.unableToFetch(errno: errno)
        }

        print("DEBUG: sysctl fetch successful, dataLength: \(dataLength)")
        guard dataLength > 0 else {
            print("DEBUG: dataLength is 0, returning empty dict")
            return [:]
        }

        let now = Date()
        var latestStats: [String: NetTrafficStat] = [:]
        var processedCount = 0
        var skippedCount = 0

        print("DEBUG: Starting to parse interface data")
        sysctlBuffer.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard var cursor = buffer.baseAddress else {
                print("DEBUG: buffer.baseAddress is nil")
                return
            }
            let endPointer = cursor.advanced(by: dataLength)
            print("DEBUG: Will parse from cursor to endPointer, dataLength: \(dataLength)")

            while cursor < endPointer {
                let messageHeader = cursor.assumingMemoryBound(to: if_msghdr.self).pointee
                let messageLength = Int(messageHeader.ifm_msglen)
                processedCount += 1

                defer {
                    cursor = cursor.advanced(by: messageLength)
                }

                guard Int32(messageHeader.ifm_type) == RTM_IFINFO else {
                    skippedCount += 1
                    continue
                }

                let flags = UInt32(messageHeader.ifm_flags)
                let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
                let isUp = (flags & UInt32(IFF_UP)) != 0

                guard !isLoopback else {
                    print("DEBUG: Skipping loopback interface (flags: \(flags))")
                    continue
                }
                guard isUp else {
                    print("DEBUG: Skipping interface that's not UP (flags: \(flags))")
                    continue
                }

                var nameBuffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                guard let namePointer = if_indextoname(UInt32(messageHeader.ifm_index), &nameBuffer)
                else {
                    print("DEBUG: if_indextoname failed for index \(messageHeader.ifm_index)")
                    continue
                }
                let interfaceName = String(cString: namePointer)
                guard !interfaceName.isEmpty else {
                    print("DEBUG: Empty interface name for index \(messageHeader.ifm_index)")
                    continue
                }

                print(
                    "DEBUG: Processing interface \(interfaceName) (flags: \(flags), up: \(isUp), loopback: \(isLoopback))"
                )

                let inboundBytes = UInt64(messageHeader.ifm_data.ifi_ibytes)
                let outboundBytes = UInt64(messageHeader.ifm_data.ifi_obytes)

                if let previous = snapshots[interfaceName] {
                    let deltaTime = now.timeIntervalSince(previous.timestamp)
                    let inboundDelta = deltaBytes(
                        current: inboundBytes, previous: previous.inboundBytes)
                    let outboundDelta = deltaBytes(
                        current: outboundBytes, previous: previous.outboundBytes)

                    let speeds = computeSpeeds(
                        deltaTime: deltaTime,
                        inboundDelta: inboundDelta,
                        outboundDelta: outboundDelta)

                    latestStats[interfaceName] = NetTrafficStat(
                        timestamp: now,
                        deltaTime: deltaTime,
                        deltaInboundBytes: inboundDelta,
                        deltaOutboundBytes: outboundDelta,
                        inboundBytesPerSecond: speeds.inbound,
                        outboundBytesPerSecond: speeds.outbound
                    )

                    snapshots[interfaceName] = InterfaceSnapshot(
                        timestamp: now,
                        inboundBytes: inboundBytes,
                        outboundBytes: outboundBytes)
                } else {
                    snapshots[interfaceName] = InterfaceSnapshot(
                        timestamp: now,
                        inboundBytes: inboundBytes,
                        outboundBytes: outboundBytes)
                    latestStats[interfaceName] = NetTrafficStat(
                        timestamp: now,
                        deltaTime: 0,
                        deltaInboundBytes: 0,
                        deltaOutboundBytes: 0,
                        inboundBytesPerSecond: 0,
                        outboundBytesPerSecond: 0
                    )
                }
            }
        }

        print(
            "DEBUG: Parsing complete. Processed \(processedCount) messages, skipped \(skippedCount), found \(latestStats.count) interfaces"
        )
        for (interface, _) in latestStats {
            print("DEBUG: Found interface: \(interface)")
        }

        return latestStats
    }

    private func deltaBytes(current: UInt64, previous: UInt64) -> UInt64 {
        if current >= previous {
            return current - previous
        } else {
            // Counter wrapped around, account for the rollover.
            return current &+ (UInt64.max - previous) &+ 1
        }
    }

    private func computeSpeeds(
        deltaTime: TimeInterval,
        inboundDelta: UInt64,
        outboundDelta: UInt64
    ) -> (inbound: Double, outbound: Double) {
        guard deltaTime <= 60 else { return (0, 0) }
        let safeInterval = max(deltaTime, 1e-3)
        let inboundSpeed = Double(inboundDelta) / safeInterval
        let outboundSpeed = Double(outboundDelta) / safeInterval
        return (inboundSpeed, outboundSpeed)
    }
}

private enum SysctlError: Error {
    case unableToQuery(errno: Int32)
    case unableToFetch(errno: Int32)
}

extension SysctlError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unableToQuery(let code):
            return "sysctl query failed (\(code)): \(String(cString: strerror(code)))"
        case .unableToFetch(let code):
            return "sysctl fetch failed (\(code)): \(String(cString: strerror(code)))"
        }
    }
}
