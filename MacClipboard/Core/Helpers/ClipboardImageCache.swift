//
//  ClipboardImageCache.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit

/// 图片展示的多级缓存：解密数据缓存 → 解码图片缓存。
/// 关键点：**加密数据先查缓存、命中则完全跳过 AES 解密与解码**——
/// 列表每次重绘（选中/滚动/悬停）都不再触发主线程解密。
enum ClipboardImageCache {

    private static let imageCache = NSCache<NSString, NSImage>()
    private static let dataCache = NSCache<NSString, NSData>()

    /// 解密数据缓存：命中返回缓存明文，未命中解密一次并缓存
    static func decryptedData(forKey key: String, encrypted: Data?) -> Data? {
        guard let encrypted else { return nil }
        let cacheKey = key as NSString
        if let hit = dataCache.object(forKey: cacheKey) {
            return hit as Data
        }
        let plain = ContentCrypto.decrypt(data: encrypted)
        dataCache.setObject(plain as NSData, forKey: cacheKey)
        return plain
    }

    /// 后台管线预热：已在后台持有明文（PNG 编码产物）时直接种入两级缓存，
    /// 入库瞬间起主线程渲染即为缓存命中
    static func seedDecrypted(forKey key: String, thumbnailPlain: Data?, fullPlain: Data?) {
        if let t = thumbnailPlain {
            dataCache.setObject(t as NSData, forKey: (key + ".t") as NSString)
            if let image = NSImage(data: t) {
                imageCache.setObject(image, forKey: (key + ".t") as NSString)
            }
        }
        if let f = fullPlain {
            dataCache.setObject(f as NSData, forKey: (key + ".f") as NSString)
            if let image = NSImage(data: f) {
                imageCache.setObject(image, forKey: (key + ".f") as NSString)
            }
        }
    }

    /// 优先缩略图，缺失时回退原图；两级缓存（数据 + 解码）
    static func image(forKey key: String, thumbnail: Data?, full: Data?) -> NSImage? {
        if let thumbnailData = decryptedData(forKey: key + ".t", encrypted: thumbnail),
           let image = decodedImage(forKey: key + ".t", data: thumbnailData) {
            return image
        }
        if let fullData = decryptedData(forKey: key + ".f", encrypted: full),
           let image = decodedImage(forKey: key + ".f", data: fullData) {
            return image
        }
        return nil
    }

    /// 历史条目（列表/卡片流，优先缩略图）
    static func image(forHistoryItem item: ClipboardItem) -> NSImage? {
        image(forKey: "history-\(item.id)", thumbnail: item.thumbnailData, full: item.imageData)
    }

    /// 历史条目原图（详情预览窗）
    static func fullImage(forHistoryItem item: ClipboardItem) -> NSImage? {
        image(forKey: "history-full-\(item.id)", thumbnail: nil, full: item.imageData)
    }

    /// 片段条目（优先缩略图）
    static func image(forSnippet snippet: Snippet) -> NSImage? {
        image(forKey: "snippet-\(snippet.id)", thumbnail: snippet.thumbnailData, full: snippet.imageData)
    }

    static func removeAll() {
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
    }

    private static func decodedImage(forKey key: String, data: Data) -> NSImage? {
        let cacheKey = key as NSString
        if let hit = imageCache.object(forKey: cacheKey) {
            return hit
        }
        guard let image = NSImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }
}
