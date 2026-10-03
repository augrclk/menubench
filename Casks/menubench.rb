cask "menubench" do
  version "1.0.2"
  sha256 "5289011693091b4180383e517a282fcedd75675198c5c123ea1d52590fcf49bf"

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
