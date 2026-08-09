//
//  SettingsView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label("通用与粘贴", systemImage: "gear")
                }
            
            IgnoreSettingsView(settings: settings)
                .tabItem {
                    Label("屏蔽过滤", systemImage: "hand.raised")
                }
            
            StorageSettingsView(settings: settings)
                .tabItem {
                    Label("存储留存", systemImage: "internaldrive")
                }
            
            AboutSettingsView()
                .tabItem {
                    Label("关于与权限", systemImage: "info.circle")
                }
        }
        .frame(width: 540, height: 380)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("基础选项") {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                Toggle("复制与粘贴播放提示音", isOn: $settings.enableSoundEffects)
            }
            
            Section("粘贴行为") {
                Toggle("选中卡片后自动触发 Cmd+V 粘贴", isOn: $settings.autoPasteAfterCopy)
                Toggle("忽略富文本样式（统一以纯文本粘贴）", isOn: $settings.pastePlaintextOnly)
            }
            
            Section(footer: Text("可在系统设置的键盘快捷键中重新进行全局绑定。").font(.caption).foregroundColor(.secondary)) {
                LabeledContent("唤出主界面", value: "Option + Shift + V (⌥⇧V)")
                LabeledContent("列表快捷键", value: "⌘C 复制  |  ⌘P 置顶  |  ⌘⌫ 删除  |  ⌘, 设置")
            }
        }
        .formStyle(.grouped)
    }
}

struct IgnoreSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("应用黑名单 (Bundle ID，逗号分隔)") {
                TextField("例如: com.apple.Terminal, com.googlecode.iterm2", text: $settings.customExcludedBundleIDs, axis: .vertical)
                    .lineLimit(2...4)
            }
            
            Section("正则表达式敏感字段屏蔽 (逗号分隔)") {
                TextField("正则匹配表达式", text: $settings.sensitiveRegexPatterns, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .formStyle(.grouped)
    }
}

struct StorageSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("保留最大条数", selection: $settings.maxHistoryCount) {
                    Text("100 条").tag(100)
                    Text("500 条").tag(500)
                    Text("1000 条").tag(1000)
                    Text("2000 条").tag(2000)
                }
            } footer: {
                Text("超出上限后将自动淘汰最旧的记录。被【置顶】的卡片不会被淘汰。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettingsView: View {
    @State private var hasAccessibilityPermission: Bool = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "paperclip.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacClipboard")
                            .font(.title2)
                            .bold()
                        Text("版本 1.1.0 (Build 2026.1)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                HStack {
                    Label("辅助功能权限 (Accessibility)", systemImage: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .orange)
                    
                    Spacer()
                    
                    Button("前往设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("系统权限状态")
            } footer: {
                Text(hasAccessibilityPermission ? "权限已正常开启，支持自动模拟 Cmd+V 执行快捷粘贴。" : "缺失辅助功能权限时，无法自动模拟 Cmd+V 粘贴。请在系统设置中允许。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkPermission()
        }
    }

    private func checkPermission() {
        hasAccessibilityPermission = AutoPaster.checkAccessibilityPermission(prompt: false)
    }
}
