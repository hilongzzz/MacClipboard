//
//  HistoryStoreTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import XCTest
import SwiftData
@testable import MacClipboard

@MainActor
final class HistoryStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var store: HistoryStore!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ClipboardItem.self, configurations: config)
        store = HistoryStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        store = nil
    }

    private func makeTextItem(_ text: String, createdBefore seconds: TimeInterval = 0) -> ClipboardItem {
        let item = ClipboardItem(type: .text, textContent: text)
        item.contentHash = ContentCrypto.hash(text: text)
        item.createdAt = Date().addingTimeInterval(-seconds)
        return item
    }

    private func allItems() throws -> [ClipboardItem] {
        try container.mainContext.fetch(FetchDescriptor<ClipboardItem>())
    }

    func testInsertAndCount() throws {
        store.store(makeTextItem("A"), limit: 100)
        store.store(makeTextItem("B"), limit: 100)
        XCTAssertEqual(try allItems().count, 2)
    }

    func testABASequenceDeduplicates() throws {
        // A → B → A：最终只保留一条 A（时间戳被刷新）
        let firstA = makeTextItem("A")
        store.store(firstA, limit: 100)
        store.store(makeTextItem("B"), limit: 100)

        let firstATimestamp = try allItems().first { $0.textContent == "A" }!.createdAt
        let outcome = store.store(makeTextItem("A"), limit: 100)

        XCTAssertEqual(outcome, .deduplicated)
        XCTAssertEqual(try allItems().count, 2)
        XCTAssertEqual(try allItems().first { $0.textContent == "A" }!.createdAt.timeIntervalSince(firstATimestamp), 0, accuracy: 2)
    }

    func testDifferentTypeSameTextNotDeduplicated() throws {
        // 相同文本但类型不同（text vs color）不算重复
        let text = ClipboardItem(type: .text, textContent: "F00")
        text.contentHash = ContentCrypto.hash(text: "F00")
        store.store(text, limit: 100)

        let color = ClipboardItem(type: .color, textContent: "F00", colorHex: "#F00")
        color.contentHash = ContentCrypto.hash(text: "F00")
        let outcome = store.store(color, limit: 100)

        XCTAssertEqual(outcome, .inserted)
        XCTAssertEqual(try allItems().count, 2)
    }

    func testLimitEvictsOldest() throws {
        store.store(makeTextItem("A", createdBefore: 30), limit: 2)
        store.store(makeTextItem("B", createdBefore: 20), limit: 2)
        store.store(makeTextItem("C", createdBefore: 10), limit: 2)

        let items = try allItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains { $0.textContent == "A" })
        XCTAssertTrue(items.contains { $0.textContent == "B" })
        XCTAssertTrue(items.contains { $0.textContent == "C" })
    }

    func testPinnedItemNeverEvicted() throws {
        let pinned = makeTextItem("PINNED", createdBefore: 100)
        pinned.isPinned = true
        store.store(pinned, limit: 2)
        store.store(makeTextItem("B", createdBefore: 20), limit: 2)
        store.store(makeTextItem("C", createdBefore: 10), limit: 2)
        store.store(makeTextItem("D", createdBefore: 5), limit: 2)

        let items = try allItems()
        // 置顶项不计入淘汰，其余保留最新 2 条
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains { $0.textContent == "PINNED" })
        XCTAssertFalse(items.contains { $0.textContent == "B" })
    }

    func testDuplicateNotSubjectToLimit() throws {
        // 去重路径不应触发淘汰
        store.store(makeTextItem("A"), limit: 2)
        store.store(makeTextItem("B"), limit: 2)
        let outcome = store.store(makeTextItem("A"), limit: 2)

        XCTAssertEqual(outcome, .deduplicated)
        XCTAssertEqual(try allItems().count, 2)
    }

    // MARK: - 自动清理

    func testPurgeExpiredRemovesOnlyOldUnpinned() throws {
        store.store(makeTextItem("OLD", createdBefore: 40 * 86400), limit: 100)
        store.store(makeTextItem("RECENT", createdBefore: 86400), limit: 100)
        let pinned = makeTextItem("OLD_PINNED", createdBefore: 40 * 86400)
        pinned.isPinned = true
        store.store(pinned, limit: 100)

        store.purgeExpired(olderThanDays: 30)

        let items = try allItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains { $0.textContent == "OLD" })
        XCTAssertTrue(items.contains { $0.textContent == "RECENT" })
        XCTAssertTrue(items.contains { $0.textContent == "OLD_PINNED" })
    }

    func testPurgeDisabledWhenDaysZero() throws {
        store.store(makeTextItem("A", createdBefore: 100 * 86400), limit: 100)
        store.purgeExpired(olderThanDays: 0)
        XCTAssertEqual(try allItems().count, 1)
    }

    func testPurgeBoundaryExactlyOnCutoffKept() throws {
        // 29 天前的保留，31 天前的删除
        store.store(makeTextItem("JUST_INSIDE", createdBefore: 29 * 86400), limit: 100)
        store.store(makeTextItem("JUST_OUTSIDE", createdBefore: 31 * 86400), limit: 100)

        store.purgeExpired(olderThanDays: 30)

        let items = try allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains { $0.textContent == "JUST_INSIDE" })
    }
}
