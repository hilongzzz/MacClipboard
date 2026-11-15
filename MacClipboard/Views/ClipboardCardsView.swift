//
//  ClipboardCardsView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import SwiftUI

/// 横向卡片流布局：类似 Paste 的预览条，可选中卡片还支持右键快速操作。
struct ClipboardCardsView: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    let onPaste: (ClipboardItem, Bool) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onSaveAsSnippet: (ClipboardItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 10) {
                    if items.isEmpty {
                        Text("暂无记录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        selectedID = item.id
                        let forcePlainText = NSEvent.modifierFlags.contains(.shift)
                        onPaste(item, forcePlainText)
                    } label: {
                        ClipboardCardView(
                            item: item,
                            isSelected: item.id == selectedID,
                            shortcutIndex: index < 9 ? index + 1 : nil
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedID) { _, newID in
                if let newID {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }
}

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    var shortcutIndex: Int? = nil

    private var briefText: String {
        (item.textContent ?? "").components(separatedBy: .newlines).first ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                switch item.type {
                case .image:
                    if let nsImage = ClipboardImageCache.image(forHistoryItem: item) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 92)
                            .clipped()
                    } else {
                        placeholder(icon: "photo", tint: .secondary)
                    }

                case .color:
                    Circle()
                        .fill(Color(hex: item.colorHex ?? "#000000"))
                        .frame(width: 52, height: 52)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .url:
                    VStack(spacing: 6) {
                        Image(systemName: "link.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text(briefText)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .file:
                    VStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                        Text(item.fileNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .rtf:
                    VStack(spacing: 4) {
                        Image(systemName: "doc.richtext.fill")
                            .foregroundColor(.purple)
                        Text(briefText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .text:
                    Text(item.textContent ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: 160, height: 92)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
            .cornerRadius(8)

            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(briefText.isEmpty ? NSLocalizedString("图片片段", comment: "") : briefText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .overlay(alignment: .topLeading) {
            if let shortcutIndex {
                Text("\(shortcutIndex)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                    .offset(x: -4, y: -4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
    }

    private var iconName: String {
        switch item.type {
        case .text: return "doc.plaintext"
        case .image: return "photo"
        case .rtf: return "doc.richtext.fill"
        case .color: return "paintpalette"
        case .url: return "link"
        case .file: return "folder"
        }
    }

    private func placeholder(icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.title)
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
