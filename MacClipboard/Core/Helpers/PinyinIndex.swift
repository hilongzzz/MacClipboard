//
//  PinyinIndex.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import Foundation

/// 拼音搜索索引：为含中文的内容生成「全拼（无声调）+ 首字母缩写」，
/// 使搜索「jd」可命中「京东优惠券」、「youhui」可命中其全拼。
/// 纯英文内容无需拼音索引（原文本身即可搜索），返回 nil。
enum PinyinIndex {

    /// 最长处理的字符数，避免超长文本的转换耗时
    private static let maxLength = 2000

    /// 例："京东优惠券" → "jing dong you hui quan jingdongyouhuiquan jdyhq"
    /// 三段式：分词全拼（CFStringTransform 按「字」输出音节）、无空格紧凑全拼（支持连续拼音查询）、首字母缩写
    static func index(for text: String) -> String? {
        let clipped = String(text.prefix(maxLength))
        guard clipped.contains(where: isChineseCharacter) else { return nil }

        let mutable = NSMutableString(string: clipped)
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let fullPinyin = (mutable as String).lowercased()

        let compactPinyin = fullPinyin.replacingOccurrences(of: " ", with: "")
        let initials = words(in: fullPinyin)
            .compactMap { $0.first.map(String.init) }
            .joined()
        return fullPinyin + " " + compactPinyin + " " + initials
    }

    /// 搜索匹配：原文或拼音索引任一命中即可
    static func matches(text: String?, pinyin: String?, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        if let text, text.localizedCaseInsensitiveContains(query) { return true }
        if let pinyin, pinyin.localizedCaseInsensitiveContains(query) { return true }
        return false
    }

    private static func isChineseCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) } ?? false
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }
}
