# iCloud 同步实测指南（免费 Apple ID 可用）

iCloud 同步功能（设置 → 存储留存 → iCloud 同步）需要**已签名的应用**才能访问 CloudKit。
使用免费 Apple ID 的个人开发签名即可完成本地实测，无需付费开发者账号。

## 步骤

### 1. 在 Xcode 中配置签名

1. 用 Xcode 打开 `MacClipboard.xcodeproj`
2. 选中 **MacClipboard** target → **Signing & Capabilities**
3. 勾选 **Automatically manage signing**，Team 选择你的 **Personal Team**（免费 Apple ID）
4. 点击 **+ Capability** 添加 **iCloud** → 勾选 **CloudKit** → Containers 中点 **+** 添加：
   ```
   iCloud.com.yunlongzhang.MacClipboard
   ```
   （与工程内 `MacClipboard/MacClipboard.entitlements` 声明的容器一致）

> 免费账号的 CloudKit 容器为开发环境容器，数据仅存在于开发环境；90 天不活跃会被 Apple 清理。

### 2. 构建（带签名的 Debug/Release）

Xcode 里直接 ⌘R 运行即可。命令行等价：

```bash
xcodebuild -project MacClipboard.xcodeproj -scheme MacClipboard -configuration Debug build \
  DEVELOPMENT_TEAM=<你的TeamID> CODE_SIGN_IDENTITY="Apple Development"
```

### 3. 验证同步

1. 启动应用 → 设置 → 存储留存 → 打开 **iCloud 同步** → **重启应用**
2. 启动日志中确认出现：`SwiftData 容器：iCloud 同步已启用`
   （若打印 `iCloud 容器创建失败，回退本地存储`，检查 iCloud 是否登录、容器是否配置）
3. 存一条片段，到 **cloudkit.com** → 你的容器 → **Development → _Default Zone** 查看数据是否上云
4. 有第二台登录同一 Apple ID 的设备时，装同一签名版本即可双向同步

### 4. 已知注意事项

- **密钥**：AES 密钥标记了 iCloud Keychain 可同步，但已存在的旧密钥需要一次 `SecItemUpdate` 迁移
  （应用已在 `loadKey` 时自动处理）；新设备**首次启动顺序**不影响解密
- **同步冲突**：SwiftData/CloudKit 按 `createdAt` 新者胜合并；同内容片段靠 `contentHash` 去重
- **关闭同步**：再次切换开关后重启，回到纯本地容器（云端数据保留在开发环境容器中）
