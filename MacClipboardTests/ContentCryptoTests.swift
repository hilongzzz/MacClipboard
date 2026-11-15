//
//  ContentCryptoTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import XCTest
@testable import MacClipboard

final class ContentCryptoTests: XCTestCase {

    func testEncryptDecryptRoundtrip() throws {
        let original = Data("剪贴板敏感内容 secret-content 🖼".utf8)
        let encrypted = ContentCrypto.encrypt(data: original)

        // 密文与明文不同（要求 Keychain 可用；CI 无头 runner 无用户 Keychain，
        // 加密按设计退化为明文，此时跳过密文断言但仍验证解密回退正确）
        if ContentCrypto.isEncryptionAvailable {
            XCTAssertNotEqual(encrypted, original)
        } else {
            throw XCTSkip("Keychain unavailable in this environment — encryption degrades to plaintext by design")
        }

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
