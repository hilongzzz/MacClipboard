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
}

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    var rtfData: Data?
    var colorHex: String?
    var urlString: String?
    var sourceAppBundleID: String?
    var createdAt: Date
    var isPinned: Bool
    
    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }
    
    init(
        type: ItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        rtfData: Data? = nil,
        colorHex: String? = nil,
        urlString: String? = nil,
        sourceAppBundleID: String? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.rtfData = rtfData
        self.colorHex = colorHex
        self.urlString = urlString
        self.sourceAppBundleID = sourceAppBundleID
        self.createdAt = Date()
        self.isPinned = false
    }
}
