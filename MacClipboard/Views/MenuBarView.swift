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
    
    var id: String { rawValue }
}

struct MenuBarView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @State private var searchText: String = ""
    @State private var selectedCategory: CategoryFilter = .all
    @State private var selectedIndex: Int = 0
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
            }
            return matchesSearch && matchesType
        }
        return result.sorted { ($0.isPinned ? 1 : 0) > ($1.isPinned ? 1 : 0) }
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
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
                    }
                
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

            // 分类筛选 Picker
            Picker("分类", selection: $selectedCategory) {
                ForEach(CategoryFilter.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .onChange(of: selectedCategory) { _, _ in
                selectedIndex = 0
            }

            Divider()

            // 列表主视图
            ClipboardListView(
                items: filteredItems,
                selectedIndex: $selectedIndex,
                onPaste: { item in pasteItem(item) },
                onDelete: { item in modelContext.delete(item) },
                onTogglePin: { item in
                    item.isPinned.toggle()
                    try? modelContext.save()
                }
            )

            Divider()

            // 底部控制与信息栏
            HStack {
                Text("共 \(items.count) 条历史")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清空历史") {
                    try? modelContext.delete(model: ClipboardItem.self, where: #Predicate { !$0.isPinned })
                }
                .font(.caption)
            }
            .padding(8)
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.downArrow) {
            if !filteredItems.isEmpty {
                selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            if !filteredItems.isEmpty {
                selectedIndex = max(selectedIndex - 1, 0)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                pasteItem(filteredItems[selectedIndex])
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: ["c", "p", ","]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if press.key == "c" {
                if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                    copyItemToPasteboard(filteredItems[selectedIndex])
                    return .handled
                }
            } else if press.key == "p" {
                if !filteredItems.isEmpty && selectedIndex < filteredItems.count {
                    let item = filteredItems[selectedIndex]
                    item.isPinned.toggle()
                    try? modelContext.save()
                    return .handled
                }
            } else if press.key == "," {
                onOpenSettings()
                return .handled
            }
            return .ignored
        }
    }

    private func pasteItem(_ item: ClipboardItem) {
        AutoPaster.paste(item: item)
        SoundManager.playPasteSound()
    }

    private func copyItemToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .rtf:
            if let rtfData = item.rtfData { pb.setData(rtfData, forType: .rtf) }
            if let text = item.textContent { pb.setString(text, forType: .string) }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) { pb.writeObjects([image]) }
        case .color, .url, .text:
            if let text = item.textContent { pb.setString(text, forType: .string) }
        }
        SoundManager.playCopySound()
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
                if let data = item.imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 50)
                        .cornerRadius(4)
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
    @Binding var selectedIndex: Int
    let onPaste: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onTogglePin: (ClipboardItem) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(action: {
                        selectedIndex = index
                        onPaste(item)
                    }) {
                        ClipboardItemRowView(item: item, isSelected: index == selectedIndex)
                    }
                    .buttonStyle(.plain)
                    .id(item.id)
                    .contextMenu {
                        Button(item.isPinned ? "取消置顶" : "置顶") {
                            onTogglePin(item)
                        }
                        Button("删除") {
                            onDelete(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < items.count {
                    let targetID = items[newIndex].id
                    proxy.scrollTo(targetID, anchor: .center)
                }
            }
        }
    }
}
