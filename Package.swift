// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSpeedMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NetSpeedMonitor",
            targets: ["NetSpeedMonitor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NetSpeedMonitor",
            path: "NetSpeedMonitor",
            exclude: [
                "Info.plist",
                "NetSpeedMonitor.entitlements",
                "icon.png"
            ],
            resources: [
                .process("Assets.xcassets"),
                .process("Preview Content")
            ]
        )
    ]
)
