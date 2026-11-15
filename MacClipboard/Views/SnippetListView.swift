//
//  SnippetListView.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import SwiftUI
import SwiftData

struct SnippetRowView: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            switch snippet.type {
            case .image:
                if let data = snippet.plainThumbnailData ?? snippet.plainImageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 40)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }

            default:
                Image(systemName: "text.quote")
                    .foregroundColor(.teal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .lineLimit(1)
                Text(snippet.groupName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

struct SnippetListView: View {
    let snippets: [Snippet]
    @Binding var selectedID: UUID?
    let onPaste: (Snippet, Bool) -> Void
    let onDelete: (Snippet) -> Void
    let onRename: (Snippet) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if snippets.isEmpty {
                    Text("暂无记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                }
                ForEach(snippets, id: \.id) { snippet in
                    Button {
                        selectedID = snippet.id
                        // Shift+点击：本次强制以纯文本粘贴
                        let forcePlainText = NSEvent.modifierFlags.contains(.shift)
                        onPaste(snippet, forcePlainText)
                    } label: {
                        SnippetRowView(snippet: snippet, isSelected: snippet.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .id(snippet.id)
                    .contextMenu {
                        Button("粘贴") {
                            onPaste(snippet, false)
                        }
                        Button("重命名") {
                            onRename(snippet)
                        }
                        Divider()
                        Button("删除") {
                            onDelete(snippet)
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
