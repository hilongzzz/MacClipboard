//
//  ContentCrypto.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/7.
//

import CryptoKit
import Foundation
import Security

/// 历史内容落盘加密与去重哈希。
/// 剪贴板历史（含图片/RTF）以 AES-GCM 加密后写入 SwiftData，
/// 密钥保存在用户 Keychain 中，与「拦截密码管理器」的产品定位保持一致的隐私标准。
enum ContentCrypto {

    private static let service = "com.yunlongzhang.MacClipboard"
    private static let account = "history-encryption-key"

    private static var key: SymmetricKey? = {
        if let data = loadKey() { return SymmetricKey(data: data) }
        let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        guard saveKey(keyData) else { return nil }
        return SymmetricKey(data: keyData)
    }()

    // MARK: - 加解密

    /// Keychain 不可用（如 CI 无头 runner）时为 false，加密退化为明文
    static var isEncryptionAvailable: Bool { key != nil }

    static func encrypt(data: Data) -> Data {
        guard let key, let sealed = try? AES.GCM.seal(data, using: key), let combined = sealed.combined else {
            return data // 加密不可用时退化为明文存储，不阻断采集
        }
        return combined
    }

    /// 解密失败时原样返回，兼容加密功能上线前留下的明文历史数据。
    static func decrypt(data: Data) -> Data {
        guard let key, let box = try? AES.GCM.SealedBox(combined: data), let plain = try? AES.GCM.open(box, using: key) else {
            return data
        }
        return plain
    }

    // MARK: - 去重哈希（基于明文内容）

    static func hash(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hash(text: String) -> String {
        hash(data: Data(text.utf8))
    }

    // MARK: - Keychain 密钥管理

    private static func loadKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            // 兼容旧密钥（本机）与 iCloud 同步密钥
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        // 旧密钥升级为可跨设备同步（开启 iCloud 同步后新设备才能解密）
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [kSecAttrSynchronizable as String: kCFBooleanTrue as Any]
        SecItemUpdate(updateQuery as CFDictionary, update as CFDictionary)

        return data
    }

    private static func saveKey(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}
