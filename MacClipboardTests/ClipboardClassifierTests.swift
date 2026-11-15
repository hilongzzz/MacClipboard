//
//  ClipboardClassifierTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import XCTest
import UniformTypeIdentifiers
@testable import MacClipboard

final class ClipboardClassifierTests: XCTestCase {

    private func snapshot(
        string: String? = nil,
        rtfData: Data? = nil,
        fileURLs: [URL] = [],
        hasImage: Bool = false,
        types: [String] = ["public.utf8-plain-text"]
    ) -> PasteboardSnapshot {
        PasteboardSnapshot(
            typeIdentifiers: types,
            rtfData: rtfData,
            string: string,
            fileURLs: fileURLs,
            hasImage: hasImage
        )
    }

    func testPlainTextInput() {
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "你好，世界")),
            .text(text: "你好，世界")
        )
    }

    func testSixDigitHexBecomesColor() {
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "1A2B3C")),
            .color(text: "1A2B3C", hex: "#1A2B3C")
        )
        // 无 # 前缀的也会补上
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "#FF8000")),
            .color(text: "#FF8000", hex: "#FF8000")
        )
    }

    func testThreeDigitHexBecomesColor() {
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "F00")),
            .color(text: "F00", hex: "#F00")
        )
    }

    func testNonHexLettersNotColor() {
        // G 不是合法 HEX 字符
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "GGGGGG")),
            .text(text: "GGGGGG")
        )
    }

    func testURLDetection() {
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "https://example.com/page?x=1")),
            .url(text: "https://example.com/page?x=1")
        )
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "http://localhost:8080")),
            .url(text: "http://localhost:8080")
        )
        // ftp 等不算网页链接
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "ftp://example.com")),
            .text(text: "ftp://example.com")
        )
    }

    func testFileURLs() {
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b report.pdf")]
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(fileURLs: urls)),
            .file(paths: ["/tmp/a.txt", "/tmp/b report.pdf"], displayName: "a.txt, b report.pdf")
        )
    }

    func testRTFHasPriority() {
        let rtf = Data("{\\rtf1\\ansi Hello}".utf8)
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(string: "Hello", rtfData: rtf)),
            .rtf(text: "Hello", rtfData: rtf)
        )
    }

    func testRTFFallbackTitle() {
        let rtf = Data("{\\rtf1}".utf8)
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(rtfData: rtf)),
            .rtf(text: "Rich Text", rtfData: rtf)
        )
    }

    func testImageDetectedByType() {
        XCTAssertEqual(
            ClipboardClassifier.classify(snapshot(hasImage: true, types: [UTType.tiff.identifier])),
            .image
        )
    }

    func testEmptySnapshotYieldsNil() {
        XCTAssertNil(ClipboardClassifier.classify(snapshot(string: "")))
        XCTAssertNil(ClipboardClassifier.classify(snapshot(string: nil, hasImage: false)))
    }
}
