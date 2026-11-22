//
//  MenuBarView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

/// 分组管理弹窗的目的
private enum GroupDialog: Identifiable {
    case renameGroup(String)
    case newGroupFor(Snippet)

    var id: String {
        switch self {
        case .renameGroup(let name): return "rename-\(name)"
        case .newGroupFor(let snippet): return "new-\(snippet.id)"
        }
    }
}

/// 面板主视图：只负责组合子视图与键盘交互；
/// 筛选排序逻辑在 PanelFilters，分组栏/列表/卡片在 Views/ 下各自独立文件。
struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings = AppSettings.shared
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @Query(sort: [SortDescriptor(\Snippet.groupName), SortDescriptor(\Snippet.createdAt, order: .reverse)])
    private var snippets: [Snippet]
    @State private var mode: PanelMode = .history
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var selectedCategory: CategoryFilter = .all
    @State private var selectedGroup: String?
    @State private var selectedID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var renamingSnippet: Snippet?
    @State private var renameText: String = ""
    @State private var showNewSnippetSheet = false
    @State private var newSnippetTitle: String = ""
    @State private var newSnippetContent: String = ""
    @State private var newSnippetGroup: String = ""
    @State private var groupDialog: GroupDialog?
    @State private var groupDialogText: String = ""
    @State private var scrollDelta: Int = 0
    @FocusState private var isSearchFocused: Bool
    @Environment(\.modelContext) private var modelContext

    var onOpenSettings: () -> Void
    var onDismiss: (() -> Void)? = nil

    var filteredItems: [ClipboardItem] {
        PanelFilters.history(items: items, query: debouncedSearchText, category: selectedCategory)
    }

    var filteredSnippets: [Snippet] {
        PanelFilters.snippets(snippets: snippets, selectedGroup: selectedGroup, query: debouncedSearchText)
    }

    var groupNames: [String] {
        Array(Set(snippets.map(\.groupName))).sorted()
    }

    private var selectedItem: ClipboardItem? {
        filteredItems.first { $0.id == selectedID } ?? filteredItems.first
    }

    private var selectedSnippet: Snippet? {
        filteredSnippets.first { $0.id == selectedSnippetID } ?? filteredSnippets.first
    }

    var body: some View {
        HStack(spacing: 0) {
            mainColumn
            // 预览窗格：大尺寸面板下实时跟随选中项
            if showPreviewPane {
                Divider()
                ClipboardPreviewPane(item: previewItem)
                    .frame(width: 210)
            }
        }
        .appAccentTint(settings.accentColorName)
        .task(id: searchText) {
            if searchText.isEmpty {
                debouncedSearchText = ""
            } else {
                // 120ms 防抖，大幅降低频繁键入时的全量拼音检索主线程压力
                try? await Task.sleep(nanoseconds: 120_000_000)
                if !Task.isCancelled {
                    debouncedSearchText = searchText
                }
            }
        }
    }

    private var showPreviewPane: Bool {
        settings.popoverSize == "large" && settings.previewPaneEnabled
    }

    /// 预览窗格内容：历史选中项，或片段选中项（构造临时条目复用同一渲染）
    private var previewItem: ClipboardItem? {
        switch mode {
        case .history:
            return selectedItem
        case .snippets:
            guard let snippet = selectedSnippet else { return nil }
            return ClipboardItem(
                type: snippet.type == .image ? .image : .text,
                textContent: snippet.textContent,
                imageData: snippet.plainImageData
            )
        }
    }

    private var mainColumn: some View {
        VStack(spacing: 0) {
            // 顶栏：搜索、保密模式与设置按钮
            PanelToolbar(
                searchText: $searchText,
                isIncognito: $monitor.isIncognito,
                isSearchFocused: $isSearchFocused,
                onOpenSettings: onOpenSettings
            )

            // 模式切换（历史 / 片段）——独立一行，避免与分类筛选在窄面板/英文下互相挤压
            HStack {
                Picker("模式", selection: $mode) {
                    ForEach(PanelMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // 分类筛选（仅历史模式）
            if mode == .history {
                HStack {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(CategoryFilter.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }

            // 片段分组过滤栏（Boards）
            if mode == .snippets {
                GroupChipsBar(
                    snippets: snippets,
                    selectedGroup: $selectedGroup,
                    onRenameGroup: { name in
                        groupDialogText = name
                        groupDialog = .renameGroup(name)
                    },
                    onDeleteGroup: { deleteGroup($0) },
                    onMove: { snippet, group in moveSnippet(snippet, to: group) }
                )
            }

            Divider()

            // 列表主视图
            if mode == .history {
                if settings.historyLayout == "strip" {
                    ClipboardCardsView(
                        items: filteredItems,
                        selectedID: $selectedID,
                        onPaste: { item, forcePlain in pasteItem(item, forcePlainText: forcePlain) },
                        onDelete: { item in deleteItem(item) },
                        onTogglePin: { item in
                            item.isPinned.toggle()
                            saveContext()
                        },
                        onSaveAsSnippet: { item in saveAsSnippet(item) }
                    )
                } else {
                    ClipboardListView(
                        items: filteredItems,
                        selectedID: $selectedID,
                        showShortcutNumbers: searchText.isEmpty,
                        scrollAnchor: scrollAnchor(forDelta: scrollDelta),
                        onPaste: { item, forcePlain in pasteItem(item, forcePlainText: forcePlain) },
                        onDelete: { item in deleteItem(item) },
                        onTogglePin: { item in
                            item.isPinned.toggle()
                            saveContext()
                        },
                        onSaveAsSnippet: { item in saveAsSnippet(item) }
                    )
                }
            } else {
                SnippetListView(
                    snippets: filteredSnippets,
                    selectedID: $selectedSnippetID,
                    groups: groupNames,
                    scrollAnchor: scrollAnchor(forDelta: scrollDelta),
                    onPaste: { snippet, forcePlain in
                        pasteSnippet(snippet, forcePlainText: forcePlain)
                    },
                    onDelete: { snippet in deleteSnippet(snippet) },
                    onRename: { snippet in
                        renamingSnippet = snippet
                        renameText = snippet.title
                    },
                    onMoveToGroup: { snippet, group in moveSnippet(snippet, to: group) },
                    onNewGroupFor: { snippet in
                        groupDialogText = ""
                        groupDialog = .newGroupFor(snippet)
                    }
                )
            }

            Divider()

            // 底部控制与信息栏
            if mode == .history {
                HStack {
                    Text("共 \(items.count) 条历史")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("清空历史") {
                        try? modelContext.delete(model: ClipboardItem.self, where: #Predicate { !$0.isPinned })
                        selectedID = nil
                        saveContext()
                    }
                    .font(.caption)
                }
                .padding(8)
            } else {
                HStack {
                    Text("共 \(snippets.count) 个片段")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        newSnippetTitle = ""
                        newSnippetContent = ""
                        newSnippetGroup = selectedGroup ?? NSLocalizedString("默认", comment: "")
                        showNewSnippetSheet = true
                    } label: {
                        Label("新建片段", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(8)
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: selectedGroup) { _, _ in
            selectedSnippetID = nil
        }
        // 新建片段编辑器
        .sheet(isPresented: $showNewSnippetSheet) {
            newSnippetSheet
        }
        // 重命名片段
        .alert("重命名片段", isPresented: Binding(
            get: { renamingSnippet != nil },
            set: { if !$0 { renamingSnippet = nil } }
        )) {
            TextField("片段标题", text: $renameText)
            Button("保存") {
                renamingSnippet?.title = renameText
                renamingSnippet = nil
                saveContext()
            }
            Button("取消", role: .cancel) { renamingSnippet = nil }
        }
        // 分组重命名 / 新建分组并移入
        .alert(groupDialogTitle, isPresented: Binding(
            get: { groupDialog != nil },
            set: { if !$0 { groupDialog = nil } }
        )) {
            TextField("分组名称", text: $groupDialogText)
            Button("保存") {
                switch groupDialog {
                case .renameGroup(let oldName):
                    renameGroup(oldName, to: groupDialogText)
                case .newGroupFor(let snippet):
                    moveSnippet(snippet, to: groupDialogText)
                case nil:
                    break
                }
                groupDialog = nil
            }
            Button("取消", role: .cancel) { groupDialog = nil }
        }
        .onKeyPress(.escape) {
            // 弹窗/编辑器打开时 ESC 由其自行消费；空闲状态下 ESC 关闭面板
            onDismiss?()
            return .handled
        }
        .onKeyPress(.downArrow) {
            scrollDelta = +1
            return moveSelection(+1)
        }
        .onKeyPress(.upArrow) {
            scrollDelta = -1
            return moveSelection(-1)
        }
        .onKeyPress(.return) {
            switch mode {
            case .history:
                guard let item = selectedItem else { return .ignored }
                pasteItem(item)
            case .snippets:
                guard let snippet = selectedSnippet else { return .ignored }
                pasteSnippet(snippet)
            }
            return .handled
        }
        // 数字 1-9：速贴第 N 条（搜索输入中时输入数字）
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            guard !isSearchFocused, let index = Int(String(press.key.character)) else { return .ignored }
            switch mode {
            case .history:
                let list = filteredItems
                guard index <= min(list.count, 9) else { return .ignored }
                pasteItem(list[index - 1], forcePlainText: press.modifiers.contains(.shift))
            case .snippets:
                let list = filteredSnippets
                guard index <= min(list.count, 9) else { return .ignored }
                pasteSnippet(list[index - 1], forcePlainText: press.modifiers.contains(.shift))
            }
            return .handled
        }
        // 空格：详情预览（搜索输入中时不拦截空格）
        .onKeyPress(keys: [" "]) { _ in
            guard !isSearchFocused, mode == .history, let item = selectedItem else { return .ignored }
            DetailPresenter.show(item: item)
            return .handled
        }
        // ⌘⌫：删除选中项
        .onKeyPress(keys: [.delete]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            switch mode {
            case .history:
                guard let item = selectedItem else { return .ignored }
                deleteItem(item)
            case .snippets:
                guard let snippet = selectedSnippet else { return .ignored }
                deleteSnippet(snippet)
            }
            return .handled
        }
        .onKeyPress(keys: ["c", "p", "s", ","]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            switch press.key {
            case "c":
                switch mode {
                case .history:
                    if let item = selectedItem {
                        AutoPaster.copy(item: item)
                        SoundManager.playCopySound()
                        return .handled
                    }
                case .snippets:
                    if let snippet = selectedSnippet {
                        AutoPaster.copy(snippet: snippet)
                        SoundManager.playCopySound()
                        return .handled
                    }
                }
            case "p":
                if mode == .history, let item = selectedItem {
                    item.isPinned.toggle()
                    saveContext()
                    return .handled
                }
            case "s":
                if mode == .history, let item = selectedItem {
                    saveAsSnippet(item)
                    return .handled
                }
            case ",":
                onOpenSettings()
                return .handled
            default:
                break
            }
            return .ignored
        }
    }

    // MARK: - 子视图

    private var newSnippetSheet: some View {
        VStack(spacing: 12) {
            Text("新建片段").font(.headline)
            TextField("片段标题", text: $newSnippetTitle)
            TextField("片段内容", text: $newSnippetContent, axis: .vertical)
                .lineLimit(3...6)
            TextField("分组名称", text: $newSnippetGroup)
            HStack {
                Spacer()
                Button("取消") { showNewSnippetSheet = false }
                Button("保存") {
                    createSnippet(title: newSnippetTitle, content: newSnippetContent, group: newSnippetGroup)
                    showNewSnippetSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newSnippetTitle.trimmingCharacters(in: .whitespaces).isEmpty
                    || newSnippetContent.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var groupDialogTitle: String {
        switch groupDialog {
        case .renameGroup: return NSLocalizedString("重命名分组", comment: "")
        case .newGroupFor: return NSLocalizedString("新建分组", comment: "")
        case nil: return ""
        }
    }

    // MARK: - 导航

    /// 键盘导航的滚动锚点：向下移动贴底、向上贴顶，减少大幅跳动
    private func scrollAnchor(forDelta delta: Int) -> UnitPoint {
        if delta > 0 { return .bottom }
        if delta < 0 { return .top }
        return .center
    }

    private func moveSelection(_ delta: Int) -> KeyPress.Result {
        switch mode {
        case .history:
            let ids = filteredItems.map(\.id)
            guard !ids.isEmpty else { return .ignored }
            let currentIndex = selectedID.flatMap { ids.firstIndex(of: $0) } ?? -1
            let nextIndex = min(max(currentIndex + delta, 0), ids.count - 1)
            selectedID = ids[nextIndex]
        case .snippets:
            let ids = filteredSnippets.map(\.id)
            guard !ids.isEmpty else { return .ignored }
            let currentIndex = selectedSnippetID.flatMap { ids.firstIndex(of: $0) } ?? -1
            let nextIndex = min(max(currentIndex + delta, 0), ids.count - 1)
            selectedSnippetID = ids[nextIndex]
        }
        return .handled
    }

    // MARK: - 历史操作

    private func pasteItem(_ item: ClipboardItem, forcePlainText: Bool = false) {
        onDismiss?()
        AutoPaster.paste(item: item, forcePlainText: forcePlainText)
        SoundManager.playPasteSound()
    }

    private func pasteSnippet(_ snippet: Snippet, forcePlainText: Bool = false) {
        onDismiss?()
        AutoPaster.paste(snippet: snippet, forcePlainText: forcePlainText)
        SoundManager.playPasteSound()
    }

    private func deleteItem(_ item: ClipboardItem) {
        if selectedID == item.id {
            selectedID = nil
        }
        DataManagement.cleanupPromiseFiles(for: item)
        modelContext.delete(item)
        saveContext()
    }

    /// 把历史卡片保存为片段（文本类存内容，图片复用已加密数据）
    private func saveAsSnippet(_ item: ClipboardItem) {
        switch item.type {
        case .text, .rtf, .url, .color:
            guard let text = item.textContent, !text.isEmpty else { return }
            let title = String(text.prefix(20))
            insertSnippet(type: .text, title: title, textContent: text, imageData: nil, thumbnailData: nil, hash: item.contentHash)
        case .image:
            // imageData / thumbnailData 已是密文，直接复用；携带 OCR 文本供搜索
            insertSnippet(
                type: .image,
                title: NSLocalizedString("图片片段", comment: ""),
                textContent: item.textContent,
                imageData: item.imageData,
                thumbnailData: item.thumbnailData,
                hash: item.contentHash
            )
        case .file:
            // 文件引用依赖路径时效性，不适合存为片段
            return
        }
    }

    // MARK: - 片段操作

    private func createSnippet(title: String, content: String, group: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }
        insertSnippet(
            type: .text,
            title: trimmedTitle,
            groupName: trimmedGroup.isEmpty ? NSLocalizedString("默认", comment: "") : trimmedGroup,
            textContent: trimmedContent,
            imageData: nil,
            thumbnailData: nil,
            hash: ContentCrypto.hash(text: trimmedContent)
        )
    }

    private func insertSnippet(
        type: ItemType,
        title: String,
        groupName: String = NSLocalizedString("默认", comment: ""),
        textContent: String?,
        imageData: Data?,
        thumbnailData: Data?,
        hash: String?
    ) {
        // 同内容片段已存在则跳过
        if let hash, !snippets.filter({ $0.contentHash == hash }).isEmpty {
            NSSound.beep()
            return
        }
        let snippet = Snippet(
            type: type,
            title: title,
            groupName: groupName,
            textContent: textContent,
            imageData: imageData,
            thumbnailData: thumbnailData,
            contentHash: hash
        )
        // 拼音索引：标题 + 内容（含图片 OCR 文本）
        snippet.pinyinIndex = PinyinIndex.index(for: title + "\n" + (textContent ?? ""))
        modelContext.insert(snippet)
        SoundManager.playCopySound()
        saveContext()
    }

    private func moveSnippet(_ snippet: Snippet, to group: String) {
        let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        snippet.groupName = trimmed
        saveContext()
    }

    private func renameGroup(_ oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else { return }
        for snippet in snippets where snippet.groupName == oldName {
            snippet.groupName = trimmed
        }
        if selectedGroup == oldName {
            selectedGroup = trimmed
        }
        saveContext()
    }

    private func deleteGroup(_ name: String) {
        let defaultGroupName = NSLocalizedString("默认", comment: "")
        for snippet in snippets where snippet.groupName == name {
            snippet.groupName = defaultGroupName
        }
        if selectedGroup == name {
            selectedGroup = nil
        }
        saveContext()
    }

    private func deleteSnippet(_ snippet: Snippet) {
        if selectedSnippetID == snippet.id {
            selectedSnippetID = nil
        }
        modelContext.delete(snippet)
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("SwiftData 保存失败: \(error)")
        }
    }
}
