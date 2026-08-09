//
//  AppSettings.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import Foundation
import SwiftUI
import Combine // 1. 必须导入 Combine 框架以提供 ObservableObject 协议支持
import ServiceManagement

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // 开机自启 (macOS 13+)
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }
    
    // 音效开关
    @AppStorage("enableSoundEffects") var enableSoundEffects: Bool = true
    
    // 自动粘贴（是否选中后自动模拟 Cmd+V）
    @AppStorage("autoPasteAfterCopy") var autoPasteAfterCopy: Bool = true
    
    // 纯文本粘贴（忽略富文本样式）
    @AppStorage("pastePlaintextOnly") var pastePlaintextOnly: Bool = false
    
    // 存储上限 (默认 500 条)
    @AppStorage("maxHistoryCount") var maxHistoryCount: Int = 500
    
    // 自定义黑名单 App Bundle ID 列表 (逗号分隔)
    @AppStorage("customExcludedBundleIDs") var customExcludedBundleIDs: String = "com.apple.Terminal,com.googlecode.iterm2"
    
    // 正则表达式过滤 (逗号分隔，匹配则不记录)
    @AppStorage("sensitiveRegexPatterns") var sensitiveRegexPatterns: String = "\\b(?:\\d[ -]*?){13,16}\\b"
    
    var excludedBundleIDSet: Set<String> {
        let defaultExcludes = [
            "com.agilebits.onepassword7",
            "com.1password.1password",
            "com.bitwarden.desktop",
            "com.keepassxc.keepassxc",
            "com.apple.keychainaccess"
        ]
        let customExcludes = customExcludedBundleIDs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
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
