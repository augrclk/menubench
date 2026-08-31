cask "menubench" do
  version :latest
  sha256 :no_check

  url "https://github.com/augrclk/menubench/releases/latest/download/Menubench.dmg",
      verified: "github.com/augrclk/menubench/"
  name "Menubench"
  desc "Local-first menu bar workbench for everyday Mac tasks"
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
