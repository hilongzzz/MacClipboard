//
//  Snippet.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import Foundation
import SwiftData

/// 片段库：用户主动保存的高频内容，不参与历史淘汰。
/// 第一期支持文本与图片两种类型（复用 ItemType 的 .text / .image）。
@Model
final class Snippet {
    var id: UUID
    var title: String
    var groupName: String
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var contentHash: String?
    var pinyinIndex: String?
    var sortOrder: Int
    var createdAt: Date

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    /// 落盘内容为 AES-GCM 密文（与历史记录共用 ContentCrypto / Keychain 密钥）
    var plainImageData: Data? {
        imageData.map(ContentCrypto.decrypt(data:))
    }

    var plainThumbnailData: Data? {
        thumbnailData.map(ContentCrypto.decrypt(data:))
    }

    init(
        type: ItemType,
        title: String,
        groupName: String,
        textContent: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        contentHash: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.groupName = groupName
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.contentHash = contentHash
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
