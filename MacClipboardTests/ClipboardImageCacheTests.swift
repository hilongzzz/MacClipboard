//
//  ClipboardImageCacheTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
import AppKit
@testable import MacClipboard

final class ClipboardImageCacheTests: XCTestCase {

    private func makeTinyPNG() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.setColor(NSColor.systemBlue, atX: 0, y: 0)
        return rep.representation(using: .png, properties: [:])!
    }

    func testDecryptedDataCacheReturnsConsistentPlain() {
        let plain = makeTinyPNG()
        let encrypted = ContentCrypto.encrypt(data: plain)

        let first = ClipboardImageCache.decryptedData(forKey: "cache-test-1", encrypted: encrypted)
        let second = ClipboardImageCache.decryptedData(forKey: "cache-test-1", encrypted: encrypted)
        XCTAssertEqual(first, plain)
        XCTAssertEqual(first, second) // 第二次来自缓存
    }

    func testNilEncryptedReturnsNil() {
        XCTAssertNil(ClipboardImageCache.decryptedData(forKey: "cache-nil", encrypted: nil))
    }

    func testHistoryItemImageRoundtrip() {
        let plain = makeTinyPNG()
        let item = ClipboardItem(type: .image)
        item.imageData = ContentCrypto.encrypt(data: plain)
        item.thumbnailData = ContentCrypto.encrypt(data: plain)

        let image = ClipboardImageCache.image(forHistoryItem: item)
        XCTAssertNotNil(image)
        // 再次调用走缓存
        let again = ClipboardImageCache.image(forHistoryItem: item)
        XCTAssertNotNil(again)

        // 原图路径
        XCTAssertNotNil(ClipboardImageCache.fullImage(forHistoryItem: item))
    }

    func testFallbackToFullWhenThumbnailMissing() {
        let plain = makeTinyPNG()
        let item = ClipboardItem(type: .image)
        item.imageData = ContentCrypto.encrypt(data: plain)
        item.thumbnailData = nil

        XCTAssertNotNil(ClipboardImageCache.image(forHistoryItem: item))
    }
}
