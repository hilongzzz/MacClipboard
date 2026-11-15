//
//  ContentCryptoTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import XCTest
@testable import MacClipboard

final class ContentCryptoTests: XCTestCase {

    func testEncryptDecryptRoundtrip() {
        let original = Data("剪贴板敏感内容 secret-content 🖼".utf8)
        let encrypted = ContentCrypto.encrypt(data: original)

        // 密文与明文不同（非退化路径）
        XCTAssertNotEqual(encrypted, original)

        XCTAssertEqual(ContentCrypto.decrypt(data: encrypted), original)
    }

    func testDecryptFallsBackToPlaintext() {
        // 加密功能上线前的历史明文数据应原样返回
        let legacy = Data("legacy plaintext".utf8)
        XCTAssertEqual(ContentCrypto.decrypt(data: legacy), legacy)
    }

    func testEmptyDataRoundtrip() {
        let empty = Data()
        XCTAssertEqual(ContentCrypto.decrypt(data: ContentCrypto.encrypt(data: empty)), empty)
    }

    func testHashDeterminism() {
        let data = Data("abc".utf8)
        XCTAssertEqual(ContentCrypto.hash(data: data), ContentCrypto.hash(data: data))
        XCTAssertNotEqual(ContentCrypto.hash(data: data), ContentCrypto.hash(data: Data("abd".utf8)))
        XCTAssertEqual(ContentCrypto.hash(text: "hello"), ContentCrypto.hash(data: Data("hello".utf8)))
    }

    func testKeyPersistsAcrossCalls() {
        // 同一密钥下：第一次加密的密文能被后续解密
        let a = ContentCrypto.encrypt(data: Data("persist".utf8))
        XCTAssertEqual(ContentCrypto.decrypt(data: a), Data("persist".utf8))
    }
}
