//
//  DataManagement.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit
import SwiftData
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

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

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

    // MARK: - 片段导入

    /// 解析并导入片段：按内容哈希去重（与现有片段、同批内重复都跳过）。
    /// 图片数据按明文导入后重新加密落盘。返回（新增条数，跳过条数）。
    @discardableResult
    static func importRecords(
        _ records: [SnippetExport],
        into modelContext: ModelContext,
        existingHashes: Set<String>
    ) -> (imported: Int, skipped: Int) {
        var hashes = existingHashes
        var imported = 0
        var skipped = 0

        for record in records {
            let type = ItemType(rawValue: record.type) ?? .text
            let plainImage = record.imageDataBase64.flatMap { Data(base64Encoded: $0) }

            let hash: String?
            switch type {
            case .image:
                hash = plainImage.map(ContentCrypto.hash(data:)) ?? record.textContent.map(ContentCrypto.hash(text:))
            default:
                hash = record.textContent.map(ContentCrypto.hash(text:)) ?? ContentCrypto.hash(text: record.title)
            }

            if let hash, hashes.contains(hash) {
                skipped += 1
                continue
            }

            let snippet = Snippet(
                type: type,
                title: record.title,
                groupName: record.groupName.isEmpty ? NSLocalizedString("默认", comment: "") : record.groupName,
                textContent: record.textContent,
                imageData: plainImage.map(ContentCrypto.encrypt(data:)),
                thumbnailData: nil,
                contentHash: hash
            )
            snippet.pinyinIndex = PinyinIndex.index(for: record.title + "\n" + (record.textContent ?? ""))
            snippet.createdAt = record.createdAt
            modelContext.insert(snippet)

            if let hash {
                hashes.insert(hash)
            }
            imported += 1
        }
        return (imported, skipped)
    }

    /// 弹出打开面板选择 JSON 并导入；返回（新增，跳过），取消返回 nil
    @MainActor
    static func pickAndImportSnippets(
        into modelContext: ModelContext,
        existingHashes: Set<String>
    ) -> (imported: Int, skipped: Int)? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([SnippetExport].self, from: data)
            let result = importRecords(records, into: modelContext, existingHashes: existingHashes)
            try? modelContext.save()
            return result
        } catch {
            print("导入片段失败: \(error)")
            NSSound.beep()
            return nil
        }
    }
}
