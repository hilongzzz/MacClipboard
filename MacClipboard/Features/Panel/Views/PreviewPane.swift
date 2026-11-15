//
//  PreviewPane.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import SwiftUI

/// 面板右侧的实时预览窗格：随键盘/点击选中即时刷新，
/// 长文本、大图、文件路径无需打开独立窗口即可阅读。
struct ClipboardPreviewPane: View {
    let item: ClipboardItem?

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    content(for: item)
                        .padding(12)
                }
            } else {
                Text("暂无记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func content(for item: ClipboardItem) -> some View {
        switch item.type {
        case .image:
            VStack(alignment: .leading, spacing: 8) {
                if let nsImage = ClipboardImageCache.image(forHistoryItem: item) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(6)
                }
                if let ocrText = item.textContent, !ocrText.isEmpty {
                    Text("识别文字")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ocrText)
                        .font(.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        case .color:
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: item.colorHex ?? "#000000"))
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                if let hex = item.colorHex {
                    KeyValueRow(label: "HEX", value: hex)
                    if let rgb = QuickActions.rgbString(fromHex: hex) {
                        KeyValueRow(label: "RGB", value: rgb)
                    }
                    if let hsl = QuickActions.hslString(fromHex: hex) {
                        KeyValueRow(label: "HSL", value: hsl)
                    }
                }
            }

        case .url:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "link.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                Text(item.textContent ?? "")
                    .font(.body)
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .file:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.filePaths ?? [], id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .foregroundColor(.secondary)
                        Text(path)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

        case .rtf:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.purple)
                Text(item.textContent ?? "")
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        default:
            // 长文本主体：限制渲染长度防止极端内容拖垮布局
            Text(String((item.textContent ?? "").prefix(20000)))
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
