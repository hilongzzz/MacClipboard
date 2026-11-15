//
//  AppIntents.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppIntents
import AppKit
import SwiftData

/// Shortcuts 动作：切换无痕模式 / 复制最新历史条目
struct ToggleIncognitoIntent: AppIntent {
    static var title: LocalizedStringResource = "切换无痕模式"
    static var description = IntentDescription("开启或关闭 MacClipboard 的无痕模式")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let monitor = (NSApp.delegate as? AppDelegate)?.monitor else {
            return .result(dialog: "无法访问应用")
        }
        monitor.isIncognito.toggle()
        return .result(dialog: monitor.isIncognito ? "无痕模式已开启" : "无痕模式已关闭")
    }
}

struct CopyLatestIntent: AppIntent {
    static var title: LocalizedStringResource = "复制最新剪贴板历史"
    static var description = IntentDescription("把最近一条历史内容写回剪贴板")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = (NSApp.delegate as? AppDelegate)?.container else {
            return .result(dialog: "应用尚未就绪")
        }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let item = try? context.fetch(descriptor).first else {
            return .result(dialog: "暂无历史记录")
        }
        AutoPaster.copy(item: item)
        return .result(dialog: "已复制最新条目")
    }
}

struct MacClipboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleIncognitoIntent(),
            phrases: [
                "\(.applicationName) 无痕",
                "切换 \(.applicationName) 无痕模式"
            ],
            systemImageName: "eye.slash"
        )
        AppShortcut(
            intent: CopyLatestIntent(),
            phrases: [
                "\(.applicationName) 复制最新",
                "\(.applicationName) 最新条目"
            ],
            systemImageName: "doc.on.doc"
        )
    }
}
