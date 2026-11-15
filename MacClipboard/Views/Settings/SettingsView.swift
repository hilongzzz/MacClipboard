//
//  SettingsView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData
import Combine

/// 设置页分区（左侧边栏导航）
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "通用与粘贴"
    case filtering = "屏蔽过滤"
    case storage = "存储留存"
    case about = "关于与权限"

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .filtering: return "hand.raised"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.displayName, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selection {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .filtering:
                    IgnoreSettingsView(settings: settings)
                case .storage:
                    StorageSettingsView(settings: settings)
                case .about:
                    AboutSettingsView()
                }
            }
            .padding()
        }
        .frame(minWidth: 640, idealWidth: 680, minHeight: 460, idealHeight: 500)
        .appAccentTint(settings.accentColorName)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("基础选项") {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                Toggle("复制与粘贴播放提示音", isOn: $settings.enableSoundEffects)
                LabeledContent("全局快捷键") {
                    HotkeyRecorderView(settings: settings)
                        .frame(width: 160, height: 28)
                }
                Picker("面板布局", selection: $settings.historyLayout) {
                    Text("文本列表").tag("list")
                    Text("横向卡片流").tag("strip")
                }
                Picker("面板尺寸", selection: $settings.popoverSize) {
                    Text("小").tag("small")
                    Text("中").tag("medium")
                    Text("大").tag("large")
                }
                Picker("主题色", selection: $settings.accentColorName) {
                    ForEach(AppTheme.presets, id: \.self) { name in
                        Text(AppTheme.displayName(for: name)).tag(name)
                    }
                }
            }

            Section("粘贴行为") {
                Toggle("选中卡片后自动触发 Cmd+V 粘贴", isOn: $settings.autoPasteAfterCopy)
                Toggle("忽略富文本样式（统一以纯文本粘贴）", isOn: $settings.pastePlaintextOnly)
            }

            Section {
                TextField("例如: tr a-z A-Z", text: $settings.customCommand, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("自定义命令")
            } footer: {
                Text("右键文本卡片运行：文本经 stdin 传入命令，stdout 写回剪贴板；留空关闭。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(footer: Text("全局快捷键在上方点击录制，须包含 ⌘/⇧/⌥/⌃ 至少一个修饰键。").font(.caption).foregroundColor(.secondary)) {
                LabeledContent("列表快捷键", value: NSLocalizedString("⌘C 复制  |  ⌘P 置顶  |  ⌘⌫ 删除  |  1-9 速贴  |  ⌘, 设置", comment: ""))
            }
        }
        .formStyle(.grouped)
    }
}

struct IgnoreSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("录制类型") {
                Toggle("记录文本与链接", isOn: $settings.recordText)
                Toggle("记录图片", isOn: $settings.recordImages)
                Toggle("记录文件", isOn: $settings.recordFiles)
                Toggle("图片 OCR 文字识别", isOn: $settings.imageOCR)
            }

            Section("应用黑名单 (Bundle ID，逗号分隔)") {
                TextField("例如: com.apple.Terminal, com.googlecode.iterm2", text: $settings.customExcludedBundleIDs, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("正则表达式敏感字段屏蔽 (每行一条)") {
                TextField("正则匹配表达式", text: $settings.sensitiveRegexPatterns, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .formStyle(.grouped)
    }
}

struct StorageSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query private var snippets: [Snippet]
    @State private var storeSizeText = "…"
    @State private var showClearAllConfirm = false

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

            Section {
                Picker("历史保留时长", selection: $settings.historyRetentionDays) {
                    Text("永久保留").tag(0)
                    Text("7 天").tag(7)
                    Text("30 天").tag(30)
                    Text("90 天").tag(90)
                }
            } footer: {
                Text("超过保留时长的未置顶历史将被自动删除，片段与置顶卡片不受影响。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("存储占用", value: storeSizeText)
                Button("导出片段为 JSON") {
                    DataManagement.exportSnippets(snippets)
                }
                Button("清空全部数据", role: .destructive) {
                    showClearAllConfirm = true
                }
            } header: {
                Text("数据管理")
            } footer: {
                Text("清空将删除全部历史与片段，且不可恢复，请先导出重要片段。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("通过 iCloud 私有容器同步", isOn: $settings.iCloudSync)
            } header: {
                Text("iCloud 同步")
            } footer: {
                Text("启用后片段与历史跨设备同步；切换后需重启应用生效。未登录 iCloud 或缺少授权时自动回退本地存储。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            storeSizeText = DataManagement.formattedStoreSize()
        }
        .alert("清空全部数据？", isPresented: $showClearAllConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("此操作将删除全部历史与片段，且不可恢复。")
        }
    }

    private func clearAllData() {
        try? modelContext.delete(model: ClipboardItem.self)
        try? modelContext.delete(model: Snippet.self)
        do {
            try modelContext.save()
        } catch {
            print("清空数据失败: \(error)")
        }
        storeSizeText = DataManagement.formattedStoreSize()
    }
}

struct AboutSettingsView: View {
    @State private var hasAccessibilityPermission: Bool = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(format: NSLocalizedString("版本 %@ (Build %@)", comment: ""), version, build)
    }

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
                        Text(versionText)
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
                Text(hasAccessibilityPermission
                     ? NSLocalizedString("权限已正常开启，支持自动模拟 Cmd+V 执行快捷粘贴。", comment: "")
                     : NSLocalizedString("缺失辅助功能权限时，无法自动模拟 Cmd+V 粘贴。请在系统设置中允许。", comment: ""))
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
