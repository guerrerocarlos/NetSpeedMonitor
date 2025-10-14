# Swift CLI - [ ] Terminal-based build and functional validation – ensure runtime parity with the former Objective-C++ bridge.
  - Build using `swift build` from the project root.
  - Run the executable with `swift run NetSpeedMonitor` or `.build/debug/NetSpeedMonitor`.
  - Verify the menu text updates for upload/download speeds across all interval options (1s–30s).
  - Toggle the "Start at Login" setting, confirm registration/unregistration succeeds.
  - Trigger the "Open Activity Monitor" button and the "Quit" action to confirm menu interactions still work.ion Plan

## Goal
Fully remove the Objective-C++ networking bridge and run the NetSpeedMonitor menu bar app entirely on Swift using Swift Package Manager and command-line tools, while keeping existing behaviour (per-interface byte deltas and live menu updates).

## Completed Checklist
- [x] Replace Objective-C++ bridge with Swift-native `NetTrafficStatReceiver`.
- [x] Update `MenuBarState` to consume Swift stats data structures.
- [x] Remove legacy Objective-C++ files and the bridging header.
- [x] Configure Swift Package Manager with appropriate executable target.

## Todo Checklist
- [ ] Functional validation – ensure runtime parity with the former Objective-C++ bridge.
  - Open the project in Xcode 15 or newer.
  - Build and run on macOS 14.6+ hardware or VM.
  - Verify the menu text updates for upload/download speeds across all interval options (1s–30s).
  - Toggle the “Start at Login” setting, confirm registration/unregistration succeeds.
  - Trigger the “Open Activity Monitor” button and the “Quit” action to confirm menu interactions still work.
- [ ] Terminal-based testing – guard critical paths around byte tracking and UI formatting.
  - Run unit tests using `swift test` to cover `NetTrafficStatReceiver` normal deltas, rollover behaviour, and >60s gaps that should zero-out speeds.
  - Add lightweight tests ensuring `MenuBarState` renders metrics with the correct unit scaling (B, KB, MB, GB, TB).
  - Use `swift test --parallel` for faster test execution and `swift test --verbose` for detailed output.
  - Consider injecting a clock/probe to make deterministic assertions on delta time calculations.
- [ ] CLI-based performance review – maintain or improve CPU footprint under frequent polling.
  - Use command-line tools like `top`, `htop`, or `Activity Monitor` to profile the app while running with the 1-second interval.
  - Run `swift build -c release` to create optimized builds for performance testing.
  - Use `time swift run -c release NetSpeedMonitor` to measure startup performance.
  - Inspect allocations from the sysctl buffer reuse to confirm no unexpected churn.
  - Capture findings for both Intel and Apple silicon if available.
- [ ] Documentation – describe the new Swift stats layer for future contributors.
  - Extend README or add a dedicated developer doc outlining how `NetTrafficStatReceiver` works and how to evolve it.
  - Note the rationale for keeping raw sysctl usage versus adopting higher-level frameworks.
- [ ] Risk review – explicitly record mitigations for known edge cases.
  - Counter rollover: ensure the `UInt64` wrap logic is documented alongside suggested monitoring.
  - Interface discovery: log and handle failures from `if_indextoname`, especially for transient or virtual interfaces.
  - Sysctl errors: decide whether repeated failures should surface UI feedback beyond logging.
- [ ] Follow-ups – track improvement ideas beyond the core migration.
  - Evaluate migrating timer management to Combine or async/await for cleaner lifecycle handling.
  - Investigate caching human-friendly interface names if future UI surfaces more detail.
  - Test on older macOS releases to determine whether the deployment target can be lowered safely.
  - Consider adding CLI arguments for debugging modes (e.g., `--verbose`, `--interface <name>`, `--interval <seconds>`).
  - Explore CI/CD integration using `swift build` and `swift test` in GitHub Actions or similar.

## CLI Development Workflow

### Building and Running
```bash
# Build the project
swift build

# Build with optimizations for release
swift build -c release

# Run the application directly
swift run NetSpeedMonitor

# Run the built executable
.build/debug/NetSpeedMonitor
```

### Testing
```bash
# Run all tests
swift test

# Run tests in parallel for faster execution
swift test --parallel

# Run tests with verbose output
swift test --verbose

# Run specific test targets
swift test --filter NetTrafficStatReceiverTests
```

### Development Tools
```bash
# Format code using swift-format (if installed)
swift-format --in-place --recursive NetSpeedMonitor/

# Check for issues with SwiftLint (if installed)
swiftlint

# Generate documentation with swift-docc (if configured)
swift package generate-documentation
```
