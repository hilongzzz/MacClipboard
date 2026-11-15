cask "macclipboard" do
  version "1.5.0"
  sha256 "df5fc71ac3864da02d4fa6c51c1142d62b68f6ec185c066bd9512156d69eb1de"

  url "https://github.com/hilongzzz/MacClipboard/releases/download/v#{version}/MacClipboard-v#{version}.dmg"
  name "MacClipboard"
  desc "Menu bar clipboard manager with snippets, boards, AES-GCM encryption"
  homepage "https://github.com/hilongzzz/MacClipboard"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "MacClipboard.app"

  zap trash: [
    "~/Library/Application Support/com.yunlongzhang.MacClipboard",
    "~/Library/Preferences/com.yunlongzhang.MacClipboard.plist",
    "~/Library/Caches/com.yunlongzhang.MacClipboard",
  ]
end
