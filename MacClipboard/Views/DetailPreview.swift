//
//  DetailPreview.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/7.
//

import AppKit
import SwiftUI

/// 空格键唤出的详情预览窗口：长文本 / 大图 / 文件列表的完整展示。
@MainActor
enum DetailPresenter {
    private static var window: NSWindow?

    static func show(item: ClipboardItem) {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.title = NSLocalizedString("详情预览", comment: "")
        window?.contentView = NSHostingView(rootView: DetailPreviewContent(item: item))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct DetailPreviewContent: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            switch item.type {
            case .image:
                if let data = item.plainImageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                }

            case .file:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.filePaths ?? [], id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()

            default:
                ScrollView {
                    Text(item.textContent ?? "")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
        .appAccentTint(AppSettings.shared.accentColorName)
    }
}
