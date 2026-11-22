//
//  ClipboardItem.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import Foundation
import SwiftData
import AppKit

enum ItemType: String, Codable {
    case text
    case image
    case rtf
    case color
    case url
    case file
}

@Model
final class ClipboardItem {
    var id: UUID
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    var rtfData: Data?
    var colorHex: String?
    var urlString: String?
    var filePaths: [String]?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var contentHash: String?
    var pinyinIndex: String?
    var sourceAppBundleID: String?
    var createdAt: Date
    var isPinned: Bool

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    /// 明文图片数据（落盘内容为 AES-GCM 密文，展示/粘贴时解密）
    var plainImageData: Data? {
        imageData.map(ContentCrypto.decrypt(data:))
    }

    var plainThumbnailData: Data? {
        thumbnailData.map(ContentCrypto.decrypt(data:))
    }

    var plainRTFData: Data? {
        rtfData.map(ContentCrypto.decrypt(data:))
    }

    var fileNames: [String] {
        (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
    }

    init(
        type: ItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        rtfData: Data? = nil,
        colorHex: String? = nil,
        urlString: String? = nil,
        sourceAppBundleID: String? = nil,
        filePaths: [String]? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.rtfData = rtfData
        self.colorHex = colorHex
        self.urlString = urlString
        self.sourceAppBundleID = sourceAppBundleID
        self.filePaths = filePaths
        self.thumbnailData = thumbnailData
        self.createdAt = Date()
        self.isPinned = false
    }
}
