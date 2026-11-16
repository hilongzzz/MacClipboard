//
//  HistoryStore.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import Foundation
import SwiftData

/// 历史记录存储：去重、淘汰、持久化。使用 in-memory ModelContainer 可直接单元测试。
@MainActor
final class HistoryStore {

    enum InsertOutcome: Equatable {
        case inserted
        case deduplicated
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 入库：历史中已存在同类型同内容（哈希一致）的记录时仅更新其时间戳
    @discardableResult
    func store(_ item: ClipboardItem, limit: Int) -> InsertOutcome {
        if let existing = findDuplicate(of: item) {
            existing.createdAt = Date()
            save()
            return .deduplicated
        }

        modelContext.insert(item)
        enforceLimit(limit: limit)
        save()
        return .inserted
    }

    func findDuplicate(of item: ClipboardItem) -> ClipboardItem? {
        let typeRaw = item.typeRaw
        let contentHash = item.contentHash
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { $0.typeRaw == typeRaw && $0.contentHash == contentHash },
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 淘汰超出上限的最旧未置顶记录（fetchCount + 定向 fetch，避免全量加载）
    func enforceLimit(limit: Int) {
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { !$0.isPinned }
        )
        guard let count = try? modelContext.fetchCount(descriptor), count > limit else { return }

        descriptor.sortBy = [SortDescriptor(\ClipboardItem.createdAt, order: .forward)]
        descriptor.fetchLimit = count - limit
        if let oldest = try? modelContext.fetch(descriptor) {
            for old in oldest {
                modelContext.delete(old)
            }
        }
    }

    /// 按保留天数自动清理：删除超过期限的未置顶历史（0 = 不清理）
    func purgeExpired(olderThanDays days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { !$0.isPinned && $0.createdAt < cutoff }
        )
        guard let expired = try? modelContext.fetch(descriptor), !expired.isEmpty else { return }
        for item in expired {
            modelContext.delete(item)
        }
        save()
    }

    /// 清空未置顶历史（clear-on-quit 使用；片段与置顶卡片保留）
    func clearUnpinned() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { !$0.isPinned }
        )
        guard let unpinned = try? modelContext.fetch(descriptor), !unpinned.isEmpty else { return }
        for item in unpinned {
            modelContext.delete(item)
        }
        save()
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            print("SwiftData 保存失败: \(error)")
        }
    }
}
