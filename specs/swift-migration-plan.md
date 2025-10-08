# Swift Migration Plan

## Goal
Fully remove the Objective-C++ networking bridge and run the NetSpeedMonitor menu bar app entirely on Swift, while keeping existing behaviour (per-interface byte deltas and live menu updates).

## Completed Checklist
- [x] Replace Objective-C++ bridge with Swift-native `NetTrafficStatReceiver`.
- [x] Update `MenuBarState` to consume Swift stats data structures.
- [x] Remove legacy Objective-C++ files and the bridging header.
- [x] Strip Objective-C++ build settings from the Xcode target.

## Todo Checklist
- [ ] Functional validation – ensure runtime parity with the former Objective-C++ bridge.
  - Open the project in Xcode 15 or newer.
  - Build and run on macOS 14.6+ hardware or VM.
  - Verify the menu text updates for upload/download speeds across all interval options (1s–30s).
  - Toggle the “Start at Login” setting, confirm registration/unregistration succeeds.
  - Trigger the “Open Activity Monitor” button and the “Quit” action to confirm menu interactions still work.
- [ ] Testing – guard critical paths around byte tracking and UI formatting.
  - Introduce unit tests for `NetTrafficStatReceiver` covering normal deltas, rollover behaviour, and >60s gaps that should zero-out speeds.
  - Add lightweight tests (or preview asserts) ensuring `MenuBarState` renders metrics with the correct unit scaling (B, KB, MB, GB, TB).
  - Consider injecting a clock/probe to make deterministic assertions on delta time calculations.
- [ ] Performance review – maintain or improve CPU footprint under frequent polling.
  - Profile the app while running with the 1-second interval to compare CPU usage against historical baselines.
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
