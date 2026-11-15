//
//  GeneralSettings
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var showLanguageRestartAlert = false

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
                Toggle("面板出现在鼠标所在屏幕", isOn: $settings.panelFollowsMouseScreen)
                Toggle("大尺寸面板显示预览窗格", isOn: $settings.previewPaneEnabled)
                Picker("应用语言（重启后生效）", selection: $settings.languageOverride) {
                    Text(NSLocalizedString("跟随系统", comment: "")).tag("system")
                    ForEach(AppLanguage.available, id: \.code) { lang in
                        Text(lang.nativeName).tag(lang.code)
                    }
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
        .onChange(of: settings.languageOverride) { _, _ in
            showLanguageRestartAlert = true
        }
        .alert("语言已切换", isPresented: $showLanguageRestartAlert) {
            Button("稍后", role: .cancel) {}
            Button("立即重启") { restartApp() }
        } message: {
            Text("新语言将在重启应用后生效。")
        }
    }

    /// 重新拉起自身：轮询等待当前实例完全退出后再 open。
    /// 固定 sleep 会有竞态（终止耗时超过 sleep 时 open 只会激活垂死的旧实例），
    /// 必须以「实例消失」为触发条件，30 秒兜底超时。
    private func restartApp() {
        let appURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [
            "-c",
            "i=0; while pgrep -x MacClipboard >/dev/null && [ $i -lt 150 ]; do sleep 0.2; i=$((i+1)); done; /usr/bin/open '\(appURL.path)'"
        ]
        try? task.run()
        NSApp.terminate(nil)
    }
}
