cask "menubench" do
  version "1.0.1"
  sha256 "02895d4c96cf8ffac572cd2af2a3a55e5ed880f70a5ae2c0341f79f182f0c4b5"

  url "https://github.com/augrclk/menubench/releases/download/v#{version}/Menubench-#{version}.dmg",
      verified: "github.com/augrclk/menubench/"
  name "Menubench"
  desc "Local-first menu bar workbench for everyday tasks"
  homepage "https://github.com/augrclk/menubench"

  depends_on formula: ["deno", "ffmpeg", "yt-dlp"]
  depends_on macos: :sonoma

  app "Menubench.app"

  zap trash: [
    "~/Library/Application Support/Menubench",
    "~/Library/Caches/com.celikugurdev.menubench",
    "~/Library/HTTPStorages/com.celikugurdev.menubench",
    "~/Library/Preferences/com.celikugurdev.menubench.plist",
    "~/Library/Saved Application State/com.celikugurdev.menubench.savedState",
  ]
end
