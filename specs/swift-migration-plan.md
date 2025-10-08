# Swift Migration Plan

## Goal
Fully remove the Objective-C++ networking bridge and run the NetSpeedMonitor menu bar app entirely on Swift, while keeping existing behaviour (per-interface byte deltas and live menu updates).

## Current State
- ✅ Swift-native `NetTrafficStatReceiver` implemented (`NetSpeedMonitor/NetTrafficStatReceiver.swift`) with sysctl polling, rollover handling, and structured logging.
- ✅ `MenuBarState` now consumes Swift structs instead of `NetTrafficStatOC`.
- ✅ Bridging header and Objective-C++/C++ source files deleted; Xcode target no longer requires Objective-C interop.

## Remaining Work
1. **Functional validation**
   - Open the project in Xcode 15+.
   - Build & run on macOS ≥ 14.6.
   - Confirm the menu text updates for upload/download speeds and matches previous behaviour.
   - Exercise update intervals, auto-launch toggle, and Activity Monitor button to guard against regressions.
2. **Testing & instrumentation**
   - Consider adding unit coverage around `NetTrafficStatReceiver` for rollover and long-interval behaviour (e.g. injecting mock snapshots).
   - Optional: add lightweight integration test to ensure `MenuBarState` formats strings correctly for various ranges.
3. **Performance watch**
   - Profile CPU usage while polling at 1s interval; ensure the Swift implementation matches or improves on the previous Objective-C++ bridge.
4. **Documentation**
   - Update README or developer docs with notes on the Swift stats layer if deeper explanation is helpful for future contributors.

## Risks & Mitigations
- **Counter handling edge cases**: rollover logic now uses `UInt64.max`; add tests to capture 32-bit rollover inputs.
- **Interface availability**: `if_indextoname` lookups might fail for virtual/temporary interfaces; ensure graceful fallback continues.
- **Error reporting**: sysctl failures log warnings; consider bubbling surfaced errors into UI if persistent.

## Follow-up Ideas
- Evaluate using Combine or async timers for cleaner scheduling.
- Cache per-interface human-readable names if app later surfaces them.
- Investigate lowering minimum macOS target once verified with real hardware.
