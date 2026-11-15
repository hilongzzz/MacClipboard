//
//  URLSchemeTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
@testable import MacClipboard

final class URLSchemeTests: XCTestCase {

    func testShowCommand() {
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://show")!), .show)
        XCTAssertEqual(URLCommand.parse(URL(string: "MACCLIPBOARD://SHOW")!), .show)
    }

    func testToggleIncognitoCommand() {
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://toggle-incognito")!), .toggleIncognito)
    }

    func testPasteCommandWithIndex() {
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://paste?n=3")!), .paste(index: 3))
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://paste")!), .paste(index: 1))
        // 非法/负数索引按 1 处理
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://paste?n=abc")!), .paste(index: 1))
        XCTAssertEqual(URLCommand.parse(URL(string: "macclipboard://paste?n=-5")!), .paste(index: 1))
    }

    func testUnknownOrForeignSchemeReturnsNil() {
        XCTAssertNil(URLCommand.parse(URL(string: "macclipboard://unknown-action")!))
        XCTAssertNil(URLCommand.parse(URL(string: "https://example.com/show")!))
    }
}
