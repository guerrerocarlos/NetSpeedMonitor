# AGENTS.md - AI Agent Handoff Documentation

## Project Overview

**NetSpeedMonitor** is a minimal macOS menu bar application that displays real-time network upload/download speeds. The project has been successfully migrated from an Objective-C++ bridge to a pure Swift implementation using Swift Package Manager for command-line development.

### Key Characteristics
- **Platform**: macOS 14.6+ (Swift Package with `.macOS(.v14)` target)
- **Architecture**: Pure Swift implementation with SwiftUI interface
- **Build System**: Swift Package Manager (Package.swift) - CLI-first development
- **Distribution**: Builds to executable that can be wrapped in `.app` bundle
- **Deployment Policy**: `.accessory` (background menu bar app, no dock icon)

## Current Status (October 2025)

### ✅ Completed Migration Work
- [x] **Objective-C++ Bridge Removal**: Completely replaced with native Swift `NetTrafficStatReceiver`
- [x] **Swift Package Manager Setup**: Configured with executable target, excludes Xcode-specific files
- [x] **Network Statistics**: Pure Swift sysctl-based network interface monitoring
- [x] **SwiftUI Interface**: Menu bar app with update interval controls, auto-launch, Activity Monitor integration
- [x] **Type Safety Fixes**: Recent compilation errors resolved (buffer type annotations, bitwise operations)

### 🔄 Current Build Status
- **Last Build**: Successfully compiles with `swift build`
- **Last Run**: Executed with `swift run NetSpeedMonitor` (user-terminated with Ctrl+C)
- **Recent Fixes Applied**: 
  - Fixed `sysctlBuffer.withUnsafeBytes` type ambiguity by adding `(buffer: UnsafeRawBufferPointer)` annotation
  - Fixed bitwise operations by casting `messageHeader.ifm_flags` to `UInt32` for compatibility with `IFF_LOOPBACK` and `IFF_UP` flags

## Architecture & Code Structure

### Core Components

#### 1. `NetTrafficStatReceiver.swift` - Network Statistics Engine
- **Purpose**: Low-level sysctl-based network interface statistics collection
- **Key Features**:
  - Uses `CTL_NET, PF_ROUTE, NET_RT_IFLIST` sysctl calls
  - Handles counter rollover with `UInt64` arithmetic 
  - Filters out loopback interfaces (`IFF_LOOPBACK`) and checks for active interfaces (`IFF_UP`)
  - Calculates per-second speeds with delta time validation (rejects >60s gaps)
  - Thread-safe with `Data` buffer reuse for performance

- **Critical Implementation Details**:
  ```swift
  // Buffer type annotation required for Swift compiler
  sysctlBuffer.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
  
  // Flag checking requires UInt32 casting
  guard (UInt32(messageHeader.ifm_flags) & UInt32(IFF_LOOPBACK)) == 0 else { continue }
  guard (UInt32(messageHeader.ifm_flags) & UInt32(IFF_UP)) != 0 else { continue }
  ```

- **Data Flow**: 
  - `getNetTrafficStatMap()` → `fetchStats()` → sysctl raw bytes → parsed interface data → `[String: NetTrafficStat]`
  - Maintains `InterfaceSnapshot` history for delta calculations
  - Returns speed calculations in bytes/second as `Double`

#### 2. `MenuBarState.swift` - State Management & Business Logic
- **Purpose**: SwiftUI observable state container managing app behavior
- **Key Features**:
  - `@AppStorage` persistence for settings (`AutoLaunchEnabled`, `NetSpeedUpdateInterval`)
  - Timer-based polling (1s, 2s, 5s, 10s, 30s intervals) 
  - Primary interface detection via SystemConfiguration framework
  - Unit conversion (B → KB → MB → GB → TB) with 1024-based scaling
  - Launch-at-login integration via `ServiceManagement.SMAppService`

- **Critical Dependencies**:
  - SystemConfiguration for network interface discovery
  - ServiceManagement for auto-launch functionality
  - Combines with `NetTrafficStatReceiver` on timer intervals

#### 3. `MenuBarIconGenerator.swift` - Dynamic Menu Bar Icon
- **Purpose**: Generates real-time text-based menu bar icons showing current speeds
- **Implementation**: Uses `NSImage` with custom drawing, monospaced font, template rendering
- **Format**: Two-line display (`↑ upload/s\n↓ download/s`)

#### 4. `MenuContentView.swift` - SwiftUI Interface
- **Purpose**: Menu dropdown content with user controls
- **Features**: Auto-launch toggle, interval selection, Activity Monitor launcher, quit button
- **Integration**: `@EnvironmentObject` connection to `MenuBarState`

#### 5. `NetSpeedMonitorApp.swift` - App Entry Point
- **Purpose**: SwiftUI app lifecycle management
- **Key Setup**: 
  - `NSApplication.shared.setActivationPolicy(.accessory)` - hides dock icon
  - `MenuBarExtra` with dynamic icon and menu content

### Data Structures

```swift
struct NetTrafficStat {
    let timestamp: Date
    let deltaTime: TimeInterval  
    let deltaInboundBytes: UInt64
    let deltaOutboundBytes: UInt64
    let inboundBytesPerSecond: Double    // Primary output for UI
    let outboundBytesPerSecond: Double   // Primary output for UI
}

enum NetSpeedUpdateInterval: Int, CaseIterable {
    case Sec1 = 1, Sec2 = 2, Sec5 = 5, Sec10 = 10, Sec30 = 30
}
```

## Development Workflow

### Building & Running
```bash
# Development build
swift build

# Optimized release build  
swift build -c release

# Run directly (primary development method)
swift run NetSpeedMonitor

# Run built executable
.build/debug/NetSpeedMonitor
```

### Testing (Planned - Not Yet Implemented)
```bash
swift test                    # Run all tests
swift test --parallel         # Faster execution
swift test --verbose          # Detailed output
```

### Performance Profiling
```bash
# Startup performance measurement
time swift run -c release NetSpeedMonitor

# Runtime monitoring (external tools)
top -pid $(pgrep NetSpeedMonitor)
```

## Known Issues & Edge Cases

### 1. **Counter Rollover Handling**
- **Issue**: Network byte counters can wrap around `UInt64.max`
- **Current Solution**: `deltaBytes()` function handles rollover with wrap-around arithmetic
- **Monitoring**: Log when rollover detected for validation

### 2. **Interface Discovery Failures**
- **Issue**: `if_indextoname()` can fail for transient/virtual interfaces
- **Current Handling**: Silently skipped with `continue`
- **Improvement Needed**: Enhanced logging and user feedback

### 3. **Sysctl Error Resilience** 
- **Issue**: Repeated sysctl failures could indicate system issues
- **Current Handling**: Logged warnings, returns empty stats
- **Decision Needed**: Whether to surface UI feedback beyond logging

### 4. **Timer Management**
- **Current**: Foundation `Timer.scheduledTimer` approach
- **Potential Improvement**: Migrate to Combine or async/await for cleaner lifecycle

## Migration Status & TODO

### Completed ✅
- Pure Swift implementation (no Objective-C++ bridge)
- Swift Package Manager configuration
- Core networking functionality verified working
- Recent compilation errors fixed

### Remaining Work 🔄

#### High Priority
1. **Functional Validation**
   - Verify all update intervals work correctly (1s-30s)
   - Test auto-launch registration/unregistration
   - Confirm Activity Monitor launcher and quit functionality

2. **Unit Testing Implementation**
   - `NetTrafficStatReceiver` delta calculations, rollover scenarios
   - `MenuBarState` unit conversion accuracy  
   - Mock clock injection for deterministic time-based testing

3. **Performance Validation**
   - CPU usage profiling at 1-second interval
   - Memory allocation analysis (sysctl buffer reuse)
   - Intel vs Apple Silicon comparison

#### Medium Priority  
4. **Documentation Enhancement**
   - Developer documentation for `NetTrafficStatReceiver` internals
   - Rationale for raw sysctl vs higher-level frameworks

5. **Risk Mitigation Documentation**
   - Counter rollover monitoring guidelines
   - Interface discovery failure handling
   - Sysctl error escalation decision framework

#### Future Enhancements
6. **CLI Arguments Support** (proposed)
   - `--verbose`, `--interface <name>`, `--interval <seconds>`
   - Debug modes for development/troubleshooting

7. **CI/CD Integration**
   - GitHub Actions with `swift build` and `swift test`
   - Cross-architecture testing automation

## Critical Dependencies

### System Frameworks
- **Foundation**: Core data types, `Date`, `Timer`, `Data`
- **AppKit**: `NSImage`, `NSApplication`, `NSWorkspace` 
- **SwiftUI**: UI framework for menu content
- **ServiceManagement**: Auto-launch functionality (`SMAppService`)
- **SystemConfiguration**: Network interface discovery
- **Darwin**: Low-level sysctl constants and functions

### Key C APIs Used
- `sysctl()` - Network interface statistics retrieval
- `if_indextoname()` - Interface index to name conversion  
- Routing table constants: `CTL_NET`, `PF_ROUTE`, `NET_RT_IFLIST`
- Interface flags: `IFF_LOOPBACK`, `IFF_UP`, `RTM_IFINFO`

## File Organization

```
NetSpeedMonitor/
├── Package.swift                     # Swift Package configuration
├── NetSpeedMonitor/                  # Source directory
│   ├── NetSpeedMonitorApp.swift     # App entry point
│   ├── MenuBarState.swift           # State management
│   ├── MenuContentView.swift        # SwiftUI menu interface
│   ├── MenuBarIconGenerator.swift   # Dynamic icon generation
│   ├── NetTrafficStatReceiver.swift # Core networking (sysctl)
│   ├── Info.plist                   # Bundle configuration  
│   ├── NetSpeedMonitor.entitlements # App permissions
│   └── Assets.xcassets/             # Icon resources
├── specs/
│   └── swift-migration-plan.md      # Migration status & CLI workflow
├── README.md                        # User documentation
└── AGENTS.md                        # This file
```

## Agent Continuation Guidelines

### For Bug Fixes
1. **Compilation Errors**: Check Swift version compatibility, especially around unsafe pointer APIs
2. **Runtime Crashes**: Usually related to sysctl buffer handling or interface name conversion
3. **Performance Issues**: Profile sysctl call frequency and buffer reuse efficiency

### For Feature Development  
1. **New CLI Arguments**: Modify `NetSpeedMonitorApp.swift` to parse command line arguments
2. **Additional Update Intervals**: Extend `NetSpeedUpdateInterval` enum and UI
3. **New Network Metrics**: Enhance `NetTrafficStat` structure and `NetTrafficStatReceiver` parsing

### For Testing Implementation
1. **Unit Tests**: Create test target in `Package.swift`
2. **Mock Networking**: Abstract sysctl calls behind protocol for testing
3. **UI Tests**: Consider XCTest integration for SwiftUI components

### Development Environment Requirements
- **macOS 14.6+** (minimum target platform)
- **Swift 5.9+** (Package.swift tools version)
- **Xcode Command Line Tools** (for system headers and sysctl constants)
- **fish shell** (user's preference, impacts terminal command syntax)

### Common Commands for Agent Workflow
```bash
# Quick build verification
swift build

# Development testing  
swift run NetSpeedMonitor

# Check for compilation errors
swift build 2>&1 | head -20

# Performance build
swift build -c release

# Clean build artifacts
swift package clean
```

## Recent Context
- **Last Modified**: October 13, 2025
- **Last Build State**: Successful compilation after type annotation fixes
- **Migration Phase**: Core functionality complete, validation phase beginning
- **Active Development**: CLI-first workflow established, Xcode dependency removed