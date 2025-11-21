cask "netspeedmonitor" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/guerrerocarlos/NetSpeedMonitor/releases/download/v#{version}/NetSpeedMonitor.app.zip"
  name "NetSpeed Monitor"
  desc "macOS menu bar application that displays real-time network upload/download speeds"
  homepage "https://github.com/guerrerocarlos/NetSpeedMonitor"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :sonoma"

  app "NetSpeedMonitor.app"

  zap trash: [
    "~/Library/Preferences/com.r3js.netspeedmonitor.plist",
    "~/Library/Saved Application State/com.r3js.netspeedmonitor.savedState",
  ]
end
