//
//  PanelFilters.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import Foundation

/// 历史列表分类
enum CategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case text = "文本"
    case image = "图片"
    case url = "链接"
    case color = "颜色"
    case file = "文件"

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString(rawValue, comment: "")
    }
}

/// 面板模式：剪贴板历史 / 片段库
enum PanelMode: String, CaseIterable, Identifiable {
    case history = "历史"
    case snippets = "片段"

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString(rawValue, comment: "")
    }
}

/// 面板列表的筛选与排序（纯逻辑，无 UI 依赖，可单元测试）
enum PanelFilters {

    /// 历史筛选：搜索（原文/拼音索引）+ 类型，置顶优先、新者次之
    static func history(
        items: [ClipboardItem],
        query: String,
        category: CategoryFilter
    ) -> [ClipboardItem] {
        let result = items.filter { item in
            let matchesSearch = query.isEmpty
                || PinyinIndex.matches(text: item.textContent, pinyin: item.pinyinIndex, query: query)
            return matchesSearch && matchesType(item, category)
        }
        return sorted(result)
    }

    static func sorted(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    /// 片段筛选：分组 + 搜索（标题/内容的原文与拼音索引）
    static func snippets(
        snippets: [Snippet],
        selectedGroup: String?,
        query: String
    ) -> [Snippet] {
        snippets.filter { snippet in
            let matchesGroup = selectedGroup == nil || snippet.groupName == selectedGroup
            let matchesSearch = query.isEmpty
                || PinyinIndex.matches(text: snippet.title, pinyin: snippet.pinyinIndex, query: query)
                || PinyinIndex.matches(text: snippet.textContent, pinyin: nil, query: query)
            return matchesGroup && matchesSearch
        }
    }

    private static func matchesType(_ item: ClipboardItem, _ category: CategoryFilter) -> Bool {
        switch category {
        case .all: return true
        case .text: return item.type == .text || item.type == .rtf
        case .image: return item.type == .image
        case .url: return item.type == .url
        case .color: return item.type == .color
        case .file: return item.type == .file
        }
    }
}
