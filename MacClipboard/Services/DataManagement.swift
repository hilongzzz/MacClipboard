//
//  DataManagement.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit
import UniformTypeIdentifiers

/// 数据管理：存储占用统计与片段导出（导出内容为解密后的明文 JSON）。
enum DataManagement {

    /// SwiftData 存储目录体积（含外部存储的图片附件）
    static func storeSizeBytes() -> Int64 {
        let storeDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacClipboard")
        return directorySize(at: storeDir)
    }

    static func formattedStoreSize() -> String {
        ByteCountFormatter.string(fromByteCount: storeSizeBytes(), countStyle: .file)
    }

    private static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - 片段导出

    struct SnippetExport: Codable {
        var title: String
        var groupName: String
        var type: String
        var textContent: String?
        var imageDataBase64: String?
        var createdAt: Date
    }

    /// 弹出保存面板导出片段；返回是否成功写出
    @MainActor
    @discardableResult
    static func exportSnippets(_ snippets: [Snippet]) -> Bool {
        guard !snippets.isEmpty else {
            NSSound.beep()
            return false
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MacClipboard-Snippets.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        let records = snippets.map { snippet -> SnippetExport in
            SnippetExport(
                title: snippet.title,
                groupName: snippet.groupName,
                type: snippet.typeRaw,
                textContent: snippet.textContent,
                imageDataBase64: snippet.plainImageData?.base64EncodedString(),
                createdAt: snippet.createdAt
            )
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return true
        } catch {
            print("导出片段失败: \(error)")
            NSSound.beep()
            return false
        }
    }
}
