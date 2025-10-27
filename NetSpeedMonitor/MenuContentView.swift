import SwiftUI
import os.log

private let loggerSubsystem = Bundle.main.bundleIdentifier ?? "NetSpeedMonitor"
public let logger = Logger(subsystem: loggerSubsystem, category: "elegracer")

struct MenuContentView: View {
    @EnvironmentObject var menuBarState: MenuBarState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Section {
                HStack {
                    Toggle("Start at Login", isOn: $menuBarState.autoLaunchEnabled)
                        .toggleStyle(.button)
                        .onChange(of: menuBarState.autoLaunchEnabled, initial: false) {
                            oldState, newState in
                            logger.info(
                                "Toggle::StartAtLogin: oldState：\(oldState), newState: \(newState)")
                        }
                }.fixedSize()
            }

            Divider()

            Section {
                HStack {
                    ForEach(NetSpeedUpdateInterval.allCases) { interval in
                        Toggle(
                            interval.displayName,
                            isOn: Binding(
                                get: { menuBarState.netSpeedUpdateInterval == interval },
                                set: { if $0 { menuBarState.netSpeedUpdateInterval = interval } }
                            )
                        )
                        .toggleStyle(.button)
                    }
                }
            } header: {
                Text("Update Interval")
            }

            Divider()

            Section {
                HStack {
                    ForEach(SpeedUnit.allCases) { unit in
                        Toggle(
                            unit.displayName,
                            isOn: Binding(
                                get: { menuBarState.speedUnit == unit },
                                set: { if $0 { menuBarState.speedUnit = unit } }
                            )
                        )
                        .toggleStyle(.button)
                    }
                }
            } header: {
                Text("Speed Unit")
            }

            Divider()

            Section {
                HStack {
                    Toggle("Show Latency & Quality", isOn: $menuBarState.showLatencyAndQuality)
                        .toggleStyle(.button)
                        .onChange(of: menuBarState.showLatencyAndQuality, initial: false) {
                            oldState, newState in
                            logger.info(
                                "Toggle::ShowLatencyAndQuality: oldState：\(oldState), newState: \(newState)"
                            )
                        }
                }.fixedSize()
            }

            Divider()

            Section {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .fixedSize()
    }
}
