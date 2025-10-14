# NetSpeedMonitor

Just a minimal menu bar macOS app.

It runs `sysctl` with c interface in a repeating timer.

Use at your own risk.

# Functions

1. Start at login.
2. Set different update intervals, now with 5 options: 1s, 2s, 5s, 10s, 30s.
3. Open Activity Monitor. When you notice abnormal network traffic, you could open Activity Monitor to check what process is the cause.

# Note

For per-process network traffic monitoring, it usually requires `nettop` which is quite cpu-heavy making it impractical to keep running at the background. Implementing it to run only when the user click the status item to make the menu showing may be a good choice.

From v1.8, the UI is built using SwiftUI, on macOS 15, with minimum system version macOS 14.6. Since I haven't successfully built it with lower version of github action runner images, it is what it is now. Later if I have the chance, I would make it compatible with lower version of macOS.

Any PR for feature enhancement or compatibility improvement is welcomed!

# Screenshot

![](./screenshot.png)

## Building

### Xcode
1. Install the full Xcode (15 or newer) and set it active: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
2. Open `NetSpeedMonitor.xcodeproj` in Xcode, select the `NetSpeedMonitor` scheme, configure code signing, then build with **Product ▸ Build** (⌘B).

### Command line via Xcode build tools
```bash
xcodebuild -project NetSpeedMonitor.xcodeproj \
           -scheme NetSpeedMonitor \
           -configuration Release \
           -derivedDataPath Build \
           clean build
```

The `.app` bundle appears at `Build/Build/Products/Release/NetSpeedMonitor.app`.

### Pure Swift toolchain (SwiftPM)
```bash
swift run --configuration release NetSpeedMonitor
```

This uses `Package.swift` to compile and launch the menu bar app without Xcode. To distribute a standalone `.app`, wrap the release binary (`.build/release/NetSpeedMonitor`) in a macOS application bundle that copies `NetSpeedMonitor/Info.plist` and embeds required resources. Some features (such as launch-at-login registration) expect the app to live inside a bundle with a stable bundle identifier.

Minimum supported macOS version remains 14.6.
