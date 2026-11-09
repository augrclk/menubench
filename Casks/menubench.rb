cask "menubench" do
  version "1.0.3"
  sha256 "a15bf141e86ae4f064465c4a9061e0f91971f65279370160de16b0cfbec5a21d"

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
