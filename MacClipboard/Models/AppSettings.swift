//
//  AppSettings.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import Foundation
import SwiftUI
import Combine
import ServiceManagement
import Carbon.HIToolbox

/// 全局设置单例。
/// 注意：不使用 `@AppStorage`——它包在 ObservableObject 内不会触发 objectWillChange，
/// 这里改为 `@Published` + UserDefaults 手动同步，键名与历史版本保持一致。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static let defaults = UserDefaults.standard

    // 开机自启 (macOS 13+)
    @Published var launchAtLogin: Bool {
        didSet {
            Self.defaults.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    // 音效开关
    @Published var enableSoundEffects: Bool {
        didSet { Self.defaults.set(enableSoundEffects, forKey: "enableSoundEffects") }
    }

    // 自动粘贴（是否选中后自动模拟 Cmd+V）
    @Published var autoPasteAfterCopy: Bool {
        didSet { Self.defaults.set(autoPasteAfterCopy, forKey: "autoPasteAfterCopy") }
    }

    // 纯文本粘贴（忽略富文本样式）
    @Published var pastePlaintextOnly: Bool {
        didSet { Self.defaults.set(pastePlaintextOnly, forKey: "pastePlaintextOnly") }
    }

    // 存储上限 (默认 500 条)
    @Published var maxHistoryCount: Int {
        didSet { Self.defaults.set(maxHistoryCount, forKey: "maxHistoryCount") }
    }

    // 自定义黑名单 App Bundle ID 列表 (逗号分隔)
    @Published var customExcludedBundleIDs: String {
        didSet { Self.defaults.set(customExcludedBundleIDs, forKey: "customExcludedBundleIDs") }
    }

    // 正则表达式过滤 (每行一条，匹配则不记录)
    @Published var sensitiveRegexPatterns: String {
        didSet { Self.defaults.set(sensitiveRegexPatterns, forKey: "sensitiveRegexPatterns") }
    }

    // 全局热键：Carbon 修饰键掩码 + 虚拟键码 + 展示字符（如 "V"）
    @Published var hotkeyModifiers: Int {
        didSet {
            Self.defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
            Self.postHotkeyChanged()
        }
    }

    @Published var hotkeyCode: Int {
        didSet {
            Self.defaults.set(hotkeyCode, forKey: "hotkeyCode")
            Self.postHotkeyChanged()
        }
    }

    @Published var hotkeyDisplay: String {
        didSet {
            Self.defaults.set(hotkeyDisplay, forKey: "hotkeyDisplay")
            Self.postHotkeyChanged()
        }
    }

    // 历史列表布局："list" 纵向列表 / "strip" 横向卡片流
    @Published var historyLayout: String {
        didSet { Self.defaults.set(historyLayout, forKey: "historyLayout") }
    }

    // 面板尺寸："small" / "medium" / "large"
    @Published var panelFollowsMouseScreen: Bool {
        didSet { Self.defaults.set(panelFollowsMouseScreen, forKey: "panelFollowsMouseScreen") }
    }

    @Published var popoverSize: String {
        didSet {
            Self.defaults.set(popoverSize, forKey: "popoverSize")
            Self.postAppearanceChanged()
        }
    }

    // 主题色："system" 或预设色名
    @Published var accentColorName: String {
        didSet {
            Self.defaults.set(accentColorName, forKey: "accentColorName")
            Self.postAppearanceChanged()
        }
    }

    // 历史自动清理保留天数（0 = 永久保留）
    @Published var historyRetentionDays: Int {
        didSet {
            Self.defaults.set(historyRetentionDays, forKey: "historyRetentionDays")
            if historyRetentionDays > 0 {
                Self.postRetentionChanged()
            }
        }
    }

    // 录制类型开关
    @Published var recordText: Bool {
        didSet { Self.defaults.set(recordText, forKey: "recordText") }
    }

    @Published var recordImages: Bool {
        didSet { Self.defaults.set(recordImages, forKey: "recordImages") }
    }

    @Published var recordFiles: Bool {
        didSet { Self.defaults.set(recordFiles, forKey: "recordFiles") }
    }

    // 图片 OCR 文字识别（识别结果参与搜索）
    @Published var imageOCR: Bool {
        didSet { Self.defaults.set(imageOCR, forKey: "imageOCR") }
    }

    // iCloud 同步（切换后需重启应用生效；失败自动回退本地）
    @Published var iCloudSync: Bool {
        didSet { Self.defaults.set(iCloudSync, forKey: "iCloudSync") }
    }

    // 自定义 shell 命令（空 = 关闭；文本经 stdin 传入，stdout 写回剪贴板）
    @Published var customCommand: String {
        didSet { Self.defaults.set(customCommand, forKey: "customCommand") }
    }

    static let hotkeyDidChangeNotification = Notification.Name("AppSettings.hotkeyDidChange")
    static let appearanceDidChangeNotification = Notification.Name("AppSettings.appearanceDidChange")
    static let retentionDidChangeNotification = Notification.Name("AppSettings.retentionDidChange")

    private static func postHotkeyChanged() {
        NotificationCenter.default.post(name: hotkeyDidChangeNotification, object: nil)
    }

    private static func postAppearanceChanged() {
        NotificationCenter.default.post(name: appearanceDidChangeNotification, object: nil)
    }

    private static func postRetentionChanged() {
        NotificationCenter.default.post(name: retentionDidChangeNotification, object: nil)
    }

    private init() {
        let d = Self.defaults
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? false
        enableSoundEffects = d.object(forKey: "enableSoundEffects") as? Bool ?? true
        autoPasteAfterCopy = d.object(forKey: "autoPasteAfterCopy") as? Bool ?? true
        pastePlaintextOnly = d.object(forKey: "pastePlaintextOnly") as? Bool ?? false
        maxHistoryCount = d.object(forKey: "maxHistoryCount") as? Int ?? 500
        customExcludedBundleIDs = d.string(forKey: "customExcludedBundleIDs")
            ?? "com.apple.Terminal,com.googlecode.iterm2"
        let defaultSensitiveRegex = "(?<!\\d)(?:\\d[ -]*?){13,16}(?!\\d)"
        if let stored = d.string(forKey: "sensitiveRegexPatterns") {
            if stored == "\\b(?:\\d[ -]*?){13,16}\\b" {
                // 旧默认正则受「逗号切分」缺陷影响从未生效，静默升级为新默认
                sensitiveRegexPatterns = defaultSensitiveRegex
            } else {
                sensitiveRegexPatterns = stored
            }
        } else {
            sensitiveRegexPatterns = defaultSensitiveRegex
        }
        // 默认 ⌥⇧V（Carbon 掩码：optionKey=8, shiftKey=2；V 键码 = 9）
        hotkeyModifiers = d.object(forKey: "hotkeyModifiers") as? Int ?? (optionKey | shiftKey)
        hotkeyCode = d.object(forKey: "hotkeyCode") as? Int ?? 9
        hotkeyDisplay = d.string(forKey: "hotkeyDisplay") ?? "V"
        historyLayout = d.string(forKey: "historyLayout") ?? "list"
        panelFollowsMouseScreen = d.object(forKey: "panelFollowsMouseScreen") as? Bool ?? false
        popoverSize = d.string(forKey: "popoverSize") ?? "medium"
        accentColorName = d.string(forKey: "accentColorName") ?? "system"
        historyRetentionDays = d.object(forKey: "historyRetentionDays") as? Int ?? 0
        recordText = d.object(forKey: "recordText") as? Bool ?? true
        recordImages = d.object(forKey: "recordImages") as? Bool ?? true
        recordFiles = d.object(forKey: "recordFiles") as? Bool ?? true
        imageOCR = d.object(forKey: "imageOCR") as? Bool ?? true
        iCloudSync = d.object(forKey: "iCloudSync") as? Bool ?? false
        customCommand = d.string(forKey: "customCommand") ?? ""
    }

    var excludedBundleIDSet: Set<String> {
        let defaultExcludes = [
            "com.agilebits.onepassword7",
            "com.1password.1password",
            "com.bitwarden.desktop",
            "com.keepassxc.keepassxc",
            "com.apple.keychainaccess"
        ]
        let customExcludes = customExcludedBundleIDs
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(defaultExcludes + customExcludes)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("更新开机自启状态失败: \(error)")
        }
    }
}
