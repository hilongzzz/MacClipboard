//
//  PanelFiltersTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/16.
//

import XCTest
@testable import MacClipboard

final class PanelFiltersTests: XCTestCase {

    private func makeItem(
        _ text: String,
        type: ItemType = .text,
        pinned: Bool = false,
        age: TimeInterval = 0
    ) -> ClipboardItem {
        let item = ClipboardItem(type: type, textContent: text)
        item.isPinned = pinned
        item.createdAt = Date().addingTimeInterval(-age)
        if type == .url {
            item.urlString = text
        }
        if type == .color {
            item.colorHex = text
        }
        item.pinyinIndex = PinyinIndex.index(for: text)
        return item
    }

    func testCategoryFilter() {
        let items = [
            makeItem("纯文本"),
            makeItem("doc.richtext", type: .rtf),
            makeItem("https://example.com", type: .url),
            makeItem("FF0000", type: .color),
            makeItem("file.txt", type: .file),
        ]
        let image = ClipboardItem(type: .image)
        image.thumbnailData = Data([1])
        items.dropFirst(0) // noop 保持结构
        var all = Array(items)
        all.append(image)

        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .all).count, 6)
        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .text).count, 2) // text + rtf
        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .image).count, 1)
        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .url).count, 1)
        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .color).count, 1)
        XCTAssertEqual(PanelFilters.history(items: all, query: "", category: .file).count, 1)
    }

    func testSearchMatchesPinyinIndex() {
        let item = makeItem("京东优惠券")
        let items = [item, makeItem("hello")]

        XCTAssertEqual(PanelFilters.history(items: items, query: "jd", category: .all).count, 1)
        XCTAssertEqual(PanelFilters.history(items: items, query: "京东", category: .all).count, 1)
        XCTAssertEqual(PanelFilters.history(items: items, query: "hello", category: .all).count, 1)
        XCTAssertEqual(PanelFilters.history(items: items, query: "nomatch", category: .all).count, 0)
    }

    func testPinnedFirstThenNewest() {
        let old = makeItem("old", age: 100)
        let pinnedOld = makeItem("pinned", pinned: true, age: 90)
        let newest = makeItem("newest", age: 1)

        let result = PanelFilters.history(
            items: [old, pinnedOld, newest],
            query: "",
            category: .all
        )
        XCTAssertEqual(result.map(\.textContent), ["pinned", "newest", "old"])
    }

    func testSnippetGroupAndSearch() {
        func makeSnippet(_ title: String, group: String, content: String? = nil) -> Snippet {
            let snippet = Snippet(type: .text, title: title, groupName: group, textContent: content ?? title)
            snippet.pinyinIndex = PinyinIndex.index(for: title)
            return snippet
        }
        let snippets = [
            makeSnippet("工作代码", group: "工作"),
            makeSnippet("生活备忘", group: "默认"),
        ]

        XCTAssertEqual(PanelFilters.snippets(snippets: snippets, selectedGroup: nil, query: "").count, 2)
        XCTAssertEqual(PanelFilters.snippets(snippets: snippets, selectedGroup: "工作", query: "").count, 1)
        XCTAssertEqual(PanelFilters.snippets(snippets: snippets, selectedGroup: "工作", query: "生活").count, 0)
        // 拼音首字母：gz 命中「工作代码」
        XCTAssertTrue(PanelFilters.snippets(snippets: snippets, selectedGroup: nil, query: "gz")
            .contains { $0.title == "工作代码" })
    }
}
