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

    /// SwiftData 存储体积。注意：非沙盒应用的 SwiftData 默认库位于
    /// ~/Library/Application Support/default.store（不在 bundle-id 子目录），
    /// 同时兼容显式指定过目录的情况。
    static func storeSizeBytes() -> Int64 {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var total: Int64 = 0

        // SwiftData 默认库（default.store 及其 WAL/外部存储）
        for suffix in ["", "-wal", "-shm", "/_EXTERNAL_DATA"] {
            let url = appSupport.appendingPathComponent("default.store\(suffix)")
            total += size(of: url)
        }

        // 显式 bundle-id 目录（历史配置兼容）
        let legacyDir = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacClipboard")
        total += size(of: legacyDir)
        return total
    }

    private static func size(of url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values?.fileSize ?? 0)
        }
        return directorySize(at: url)
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

    // MARK: - Promise 临时文件清理

    /// 清理特定条目关联的 Promise 临时目录
    static func cleanupPromiseFiles(for item: ClipboardItem) {
        guard let paths = item.filePaths else { return }
        cleanupPromiseFiles(in: paths)
    }

    /// 清理路径列表中的 Promise 临时目录
    static func cleanupPromiseFiles(in paths: [String]) {
        let tempPrefix = FileManager.default.temporaryDirectory.path + "/MacClipboard-Promise-"
        let fm = FileManager.default
        for path in paths {
            if path.hasPrefix(tempPrefix) {
                let url = URL(fileURLWithPath: path)
                let parentDir = url.deletingLastPathComponent()
                if parentDir.path.hasPrefix(tempPrefix) {
                    try? fm.removeItem(at: parentDir)
                } else if url.path.hasPrefix(tempPrefix) {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    /// 清理系统临时目录下所有遗留的 MacClipboard-Promise-* 文件夹
    static func cleanupAllPromiseTemporaryDirectories() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        guard let entries = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.lastPathComponent.hasPrefix("MacClipboard-Promise-") {
            try? fm.removeItem(at: entry)
        }
    }
}
