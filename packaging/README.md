# Homebrew 分发

本目录存放 Homebrew cask 公式。Homebrew 官方仓库要求一定的知名度，当前采用**自建 tap** 方式分发。

## 一次性准备：创建 tap 仓库

1. 在 GitHub 上新建仓库 `hilongzzz/homebrew-macclipboard`
2. 把 `packaging/Casks/macclipboard.rb` 复制到该仓库的 `Casks/macclipboard.rb`
3. 提交推送

之后用户即可安装：

```bash
brew tap hilongzzz/macclipboard https://github.com/hilongzzz/homebrew-macclipboard
brew install --cask macclipboard
```

## 发新版时同步更新

每次发布新 Release 后：

1. 下载 DMG，计算 sha256：
   ```bash
   curl -sL -o /tmp/mc.dmg "https://github.com/hilongzzz/MacClipboard/releases/download/v<版本>/MacClipboard-v<版本>.dmg"
   shasum -a 256 /tmp/mc.dmg
   ```
2. 更新 tap 仓库中 cask 的 `version` 与 `sha256`（`livecheck` 已配置跟随 GitHub latest，`brew upgrade --cask --greedy` 用户会收到提示）
3. 提交推送 tap 仓库

## 备注

- 未公证版本安装后首次打开需要右键 →「打开」绕过 Gatekeeper；自动 Cmd+V 需授予辅助功能权限
- 待有 Apple Developer 账号完成公证后，可评估提交到 homebrew 官方 cask 仓库
