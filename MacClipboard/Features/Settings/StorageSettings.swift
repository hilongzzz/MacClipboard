//
//  StorageSettings
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

struct StorageSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query private var snippets: [Snippet]
    @State private var storeSizeText = "…"
    @State private var showClearAllConfirm = false
    @State private var importResult: (imported: Int, skipped: Int)?

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
                Toggle("退出时清空未置顶历史", isOn: $settings.clearOnQuit)
            } footer: {
                Text("退出时将清除未置顶的历史记录，片段与置顶卡片保留。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("存储占用", value: storeSizeText)
                Button("导出片段为 JSON") {
                    DataManagement.exportSnippets(snippets)
                }
                Button("从 JSON 导入片段") {
                    if let result = DataManagement.pickAndImportSnippets(
                        into: modelContext,
                        existingHashes: Set(snippets.compactMap(\.contentHash))
                    ) {
                        importResult = result
                    }
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
        .alert("导入完成", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("好") { importResult = nil }
        } message: {
            Text(String(
                format: NSLocalizedString("新增 %lld 条片段，跳过 %lld 条重复。", comment: ""),
                importResult?.imported ?? 0,
                importResult?.skipped ?? 0
            ))
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
