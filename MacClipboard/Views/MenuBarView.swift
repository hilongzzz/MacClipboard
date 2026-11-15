//
//  MenuBarView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

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

struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @Query(sort: [SortDescriptor(\Snippet.groupName), SortDescriptor(\Snippet.createdAt, order: .reverse)])
    private var snippets: [Snippet]
    @State private var mode: PanelMode = .history
    @State private var searchText: String = ""
    @State private var selectedCategory: CategoryFilter = .all
    @State private var selectedID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var renamingSnippet: Snippet?
    @State private var renameText: String = ""
    @State private var showNewSnippetSheet = false
    @State private var newSnippetTitle: String = ""
    @State private var newSnippetContent: String = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.modelContext) private var modelContext

    var onOpenSettings: () -> Void

    var filteredItems: [ClipboardItem] {
        let result = items.filter { item in
            let matchesSearch = searchText.isEmpty || item.textContent?.localizedCaseInsensitiveContains(searchText) == true
            let matchesType: Bool
            switch selectedCategory {
            case .all: matchesType = true
            case .text: matchesType = (item.type == .text || item.type == .rtf)
            case .image: matchesType = (item.type == .image)
            case .url: matchesType = (item.type == .url)
            case .color: matchesType = (item.type == .color)
            case .file: matchesType = (item.type == .file)
            }
            return matchesSearch && matchesType
        }
        return result.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.textContent?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    private var selectedItem: ClipboardItem? {
        filteredItems.first { $0.id == selectedID } ?? filteredItems.first
    }

    private var selectedSnippet: Snippet? {
        filteredSnippets.first { $0.id == selectedSnippetID } ?? filteredSnippets.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏：搜索、保密模式与设置按钮
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索剪切板 (⌥⇧V)...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)

                Toggle(isOn: $monitor.isIncognito) {
                    Image(systemName: monitor.isIncognito ? "eye.slash.fill" : "eye")
                }
                .toggleStyle(.button)
                .help("无痕模式")

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("偏好设置")
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))

            // 模式切换（历史 / 片段）+ 分类筛选（仅历史模式）
            HStack(spacing: 8) {
                Picker("模式", selection: $mode) {
                    ForEach(PanelMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                if mode == .history {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(CategoryFilter.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            // 列表主视图
            if mode == .history {
                ClipboardListView(
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
                SnippetListView(
                    snippets: filteredSnippets,
                    selectedID: $selectedSnippetID,
                    onPaste: { snippet, forcePlain in
                        AutoPaster.paste(snippet: snippet, forcePlainText: forcePlain)
                        SoundManager.playPasteSound()
                    },
                    onDelete: { snippet in deleteSnippet(snippet) },
                    onRename: { snippet in
                        renamingSnippet = snippet
                        renameText = snippet.title
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
        // 新建片段编辑器
        .sheet(isPresented: $showNewSnippetSheet) {
            VStack(spacing: 12) {
                Text("新建片段").font(.headline)
                TextField("片段标题", text: $newSnippetTitle)
                TextField("片段内容", text: $newSnippetContent, axis: .vertical)
                    .lineLimit(3...6)
                HStack {
                    Spacer()
                    Button("取消") { showNewSnippetSheet = false }
                    Button("保存") {
                        createSnippet(title: newSnippetTitle, content: newSnippetContent)
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
        // 重命名
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
        .onKeyPress(.downArrow) {
            moveSelection(+1)
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
        }
        .onKeyPress(.return) {
            switch mode {
            case .history:
                guard let item = selectedItem else { return .ignored }
                pasteItem(item)
            case .snippets:
                guard let snippet = selectedSnippet else { return .ignored }
                AutoPaster.paste(snippet: snippet)
                SoundManager.playPasteSound()
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

    // MARK: - 导航

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
        AutoPaster.paste(item: item, forcePlainText: forcePlainText)
        SoundManager.playPasteSound()
    }

    private func deleteItem(_ item: ClipboardItem) {
        if selectedID == item.id {
            selectedID = nil
        }
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
            // imageData / thumbnailData 已是密文，直接复用
            insertSnippet(
                type: .image,
                title: NSLocalizedString("图片片段", comment: ""),
                textContent: nil,
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

    private func createSnippet(title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }
        insertSnippet(
            type: .text,
            title: trimmedTitle,
            textContent: trimmedContent,
            imageData: nil,
            thumbnailData: nil,
            hash: ContentCrypto.hash(text: trimmedContent)
        )
    }

    private func insertSnippet(
        type: ItemType,
        title: String,
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
            groupName: NSLocalizedString("默认", comment: ""),
            textContent: textContent,
            imageData: imageData,
            thumbnailData: thumbnailData,
            contentHash: hash
        )
        modelContext.insert(snippet)
        SoundManager.playCopySound()
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

struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            switch item.type {
            case .color:
                Circle()
                    .fill(Color(hex: item.colorHex ?? "#000000"))
                    .frame(width: 18, height: 18)
                Text(item.textContent ?? "")
                    .font(.system(.body, design: .monospaced))

            case .url:
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                Text(item.textContent ?? "")
                    .lineLimit(1)
                    .foregroundColor(.blue)

            case .rtf:
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(.purple)
                Text(item.textContent ?? "")
                    .lineLimit(2)

            case .image:
                // 优先使用预生成缩略图，避免列表解码原始大图
                if let data = item.plainThumbnailData ?? item.plainImageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 50)
                        .cornerRadius(4)
                }

            case .file:
                Image(systemName: "folder.fill")
                    .foregroundColor(.yellow)
                Text(item.fileNames.joined(separator: ", "))
                    .lineLimit(2)
                if item.fileNames.count > 1 {
                    Text("\(item.fileNames.count) 个文件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .text:
                Image(systemName: "doc.plaintext")
                    .foregroundColor(.secondary)
                Text(item.textContent ?? "")
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

struct ClipboardListView: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    let onPaste: (ClipboardItem, Bool) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    let onSaveAsSnippet: (ClipboardItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if items.isEmpty {
                    Text("暂无记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                }
                ForEach(items, id: \.id) { item in
                    Button {
                        selectedID = item.id
                        // Shift+点击：本次强制以纯文本粘贴
                        let forcePlainText = NSEvent.modifierFlags.contains(.shift)
                        onPaste(item, forcePlainText)
                    } label: {
                        ClipboardItemRowView(item: item, isSelected: item.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .id(item.id)
                    .contextMenu {
                        Button(item.isPinned ? "取消置顶" : "置顶") {
                            onTogglePin(item)
                        }

                        Button("保存为片段") {
                            onSaveAsSnippet(item)
                        }

                        // 按类型提供的快速操作
                        if item.type == .url, let urlString = item.urlString ?? item.textContent {
                            Button("打开链接") {
                                QuickActions.openURL(urlString)
                            }
                        }
                        if item.type == .file, let firstPath = (item.filePaths ?? []).first {
                            Button("在 Finder 中显示") {
                                QuickActions.revealInFinder(firstPath)
                            }
                        }
                        if item.type == .text, let text = item.textContent {
                            Button("用 Google 搜索") {
                                QuickActions.searchWeb(text)
                            }
                        }
                        if item.type == .color, let hex = item.colorHex {
                            if let rgb = QuickActions.rgbString(fromHex: hex) {
                                Button("复制 RGB") {
                                    QuickActions.copyText(rgb)
                                }
                            }
                            if let hsl = QuickActions.hslString(fromHex: hex) {
                                Button("复制 HSL") {
                                    QuickActions.copyText(hsl)
                                }
                            }
                        }

                        Divider()
                        Button("删除") {
                            onDelete(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedID) { _, newID in
                if let newID {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }
}
