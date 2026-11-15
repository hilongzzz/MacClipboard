//
//  DataManagementTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
import SwiftData
@testable import MacClipboard

@MainActor
final class DataManagementTests: XCTestCase {

    func testExportImportRoundtrip() throws {
        let record = DataManagement.SnippetExport(
            title: "问候语",
            groupName: "工作",
            type: ItemType.text.rawValue,
            textContent: "你好，世界 🌏",
            imageDataBase64: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try DataManagement.encoder.encode([record])
        let decoded = try DataManagement.decoder.decode([DataManagement.SnippetExport].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].title, "问候语")
        XCTAssertEqual(decoded[0].groupName, "工作")
        XCTAssertEqual(decoded[0].textContent, "你好，世界 🌏")
        XCTAssertEqual(decoded[0].createdAt.timeIntervalSince1970, 1_700_000_000, accuracy: 1)
    }

    func testImageImportEncryptsAndRoundtrips() throws {
        let plainImage = Data("fake-png-bytes".utf8)
        let record = DataManagement.SnippetExport(
            title: "图片片段",
            groupName: "默认",
            type: ItemType.image.rawValue,
            textContent: "OCR 文本",
            imageDataBase64: plainImage.base64EncodedString(),
            createdAt: Date()
        )

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Snippet.self, configurations: config)
        let context = container.mainContext

        let result = DataManagement.importRecords([record], into: context, existingHashes: [])
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        let snippets = try context.fetch(FetchDescriptor<Snippet>())
        XCTAssertEqual(snippets.count, 1)
        let snippet = snippets[0]
        // 落盘为密文、读回为明文；Keychain 不可用（CI）时按设计退化为明文
        if ContentCrypto.isEncryptionAvailable {
            XCTAssertNotEqual(snippet.imageData, plainImage)
        }
        XCTAssertEqual(snippet.plainImageData, plainImage)
        XCTAssertEqual(snippet.textContent, "OCR 文本")
        XCTAssertNotNil(snippet.pinyinIndex)
    }

    func testImportDeduplicatesAgainstExistingAndWithinBatch() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Snippet.self, configurations: config)
        let context = container.mainContext

        // 已有片段，内容哈希与待导入的一条相同
        let existing = Snippet(
            type: .text, title: "已有", groupName: "默认",
            textContent: "重复内容", imageData: nil, thumbnailData: nil,
            contentHash: ContentCrypto.hash(text: "重复内容")
        )
        context.insert(existing)
        try context.save()

        let duplicateRecord = DataManagement.SnippetExport(
            title: "重复内容", groupName: "默认", type: "text",
            textContent: "重复内容", imageDataBase64: nil, createdAt: Date()
        )
        let freshRecord = DataManagement.SnippetExport(
            title: "新片段", groupName: "默认", type: "text",
            textContent: "全新内容", imageDataBase64: nil, createdAt: Date()
        )
        let batchDuplicate = DataManagement.SnippetExport(
            title: "新片段副本", groupName: "默认", type: "text",
            textContent: "全新内容", imageDataBase64: nil, createdAt: Date()
        )

        let result = DataManagement.importRecords(
            [duplicateRecord, freshRecord, batchDuplicate],
            into: context,
            existingHashes: Set([existing.contentHash!])
        )
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 2)

        let snippets = try context.fetch(FetchDescriptor<Snippet>())
        XCTAssertEqual(snippets.count, 2)
    }
}
