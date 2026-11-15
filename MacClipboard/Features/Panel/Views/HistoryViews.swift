//
//  HistoryViews.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import SwiftUI

private func actionTitleKey(_ action: AIAssistant.Action) -> String {
    switch action {
    case .summarize: return "AI 摘要"
    case .translate: return "AI 翻译"
    case .polish: return "AI 润色"
    }
}

/// 历史卡片的公共右键菜单（列表与卡片流共用）
@ViewBuilder
func clipboardItemContextMenu(
    item: ClipboardItem,
    onTogglePin: @escaping () -> Void,
    onSaveAsSnippet: @escaping () -> Void,
    onDelete: @escaping () -> Void
) -> some View {
    Button(item.isPinned ? "取消置顶" : "置顶", action: onTogglePin)

    Button("保存为片段", action: onSaveAsSnippet)

    // 按类型提供的快速操作
    if item.type == .url, let urlString = item.urlString ?? item.textContent {
        Button("打开链接") {
            QuickActions.openURL(urlString)
        }
    }
    if item.type == .file, let firstPath = (item.filePaths ?? []).first {
        Button("在 Finder 中显示") {
            QuickActions.revealInFinder(firstPath)
        }
    }
    if item.type == .text, let text = item.textContent {
        Button("用 Google 搜索") {
            QuickActions.searchWeb(text)
        }

        // Apple Intelligence 动作（macOS 26+ 端上模型可用时）
        if AIAssistant.isAvailable, text.count <= 2000 {
            Menu("AI 助手") {
                ForEach(AIAssistant.Action.allCases, id: \.self) { action in
                    Button(actionTitleKey(action)) {
                        AIAssistant.performAndShow(action: action, text: text)
                    }
                }
            }
        }

        // 自定义 shell 命令
        if !AppSettings.shared.customCommand.trimmingCharacters(in: .whitespaces).isEmpty {
            Button("运行自定义命令") {
                if let result = CustomCommand.run(command: AppSettings.shared.customCommand, on: text) {
                    QuickActions.copyText(result)
                } else {
                    NSSound.beep()
                }
            }
        }
    }
    if item.type == .color, let hex = item.colorHex {
        if let rgb = QuickActions.rgbString(fromHex: hex) {
            Button("复制 RGB") {
                QuickActions.copyText(rgb)
            }
        }
        if let hsl = QuickActions.hslString(fromHex: hex) {
            Button("复制 HSL") {
                QuickActions.copyText(hsl)
            }
        }
    }

    Divider()
    Button("删除", action: onDelete)
}

struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    var shortcutIndex: Int? = nil

    @State private var isHovering = false

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovering { return Color.primary.opacity(0.05) }
        return .clear
    }

    var body: some View {
        HStack(spacing: 10) {
            if let shortcutIndex {
                Text("\(shortcutIndex)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.6)))
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            switch item.type {
            case .color:
                Circle()
                    .fill(Color(hex: item.colorHex ?? "#000000"))
                    .frame(width: 18, height: 18)
                Text(item.textContent ?? "")
                    .font(.system(.body, design: .monospaced))

            case .url:
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                Text(item.textContent ?? "")
                    .lineLimit(1)
                    .foregroundColor(.blue)

            case .rtf:
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.purple)
                Text(item.textContent ?? "")
                    .lineLimit(2)

            case .image:
                // 优先使用预生成缩略图 + 共享解码缓存，避免列表反复解码原始大图
                if let nsImage = ClipboardImageCache.image(forHistoryItem: item) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 50)
                        .cornerRadius(4)
                }

            case .file:
                Image(systemName: "folder.fill")
                    .foregroundColor(.yellow)
                Text(item.fileNames.joined(separator: ", "))
                    .lineLimit(2)
                if item.fileNames.count > 1 {
                    Text("\(item.fileNames.count) 个文件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .text:
                Image(systemName: "doc.plaintext")
                    .foregroundColor(.secondary)
                Text(item.textContent ?? "")
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(rowBackground)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

struct ClipboardListView: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    var showShortcutNumbers: Bool = false
    var scrollAnchor: UnitPoint = .center
    let onPaste: (ClipboardItem, Bool) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onSaveAsSnippet: (ClipboardItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if items.isEmpty {
                    Text("暂无记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selectedID = item.id
                        // Shift+点击：本次强制以纯文本粘贴
                        let forcePlainText = NSEvent.modifierFlags.contains(.shift)
                        onPaste(item, forcePlainText)
                    } label: {
                        ClipboardItemRowView(
                            item: item,
                            isSelected: item.id == selectedID,
                            shortcutIndex: showShortcutNumbers && index < 9 ? index + 1 : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .id(item.id)
                    .contextMenu {
                        clipboardItemContextMenu(
                            item: item,
                            onTogglePin: { onTogglePin(item) },
                            onSaveAsSnippet: { onSaveAsSnippet(item) },
                            onDelete: { onDelete(item) }
                        )
                    }
                }
            }
            .listStyle(.inset)
            .onChange(of: selectedID) { _, newID in
                if let newID {
                    proxy.scrollTo(newID, anchor: scrollAnchor)
                }
            }
        }
    }
}
