//
//  ClipboardImageCache.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit

/// 解码后的图片缓存：列表行、卡片流、片段行、详情预览共用。
/// NSCache 在内存紧张时自动逐出，避免历史滚动时反复解码缩略图/原图。
enum ClipboardImageCache {

    private static let cache = NSCache<NSString, NSImage>()

    static func image(forKey key: String, thumbnail: Data?, full: Data?) -> NSImage? {
        guard let data = thumbnail ?? full else { return nil }
        let cacheKey = key as NSString
        if let hit = cache.object(forKey: cacheKey) {
            return hit
        }
        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    static func image(forHistoryItem item: ClipboardItem) -> NSImage? {
        image(forKey: "history-\(item.id)", thumbnail: item.plainThumbnailData, full: item.plainImageData)
    }

    static func image(forSnippet snippet: Snippet) -> NSImage? {
        image(forKey: "snippet-\(snippet.id)", thumbnail: snippet.plainThumbnailData, full: snippet.plainImageData)
    }

    static func removeAll() {
        cache.removeAllObjects()
    }
}
