//
//  GroupChipsBar.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import SwiftUI
import SwiftData

/// 片段分组（Boards）过滤栏：chip 过滤、拖拽归类、右键重命名/删除分组
struct GroupChipsBar: View {
    let snippets: [Snippet]
    @Binding var selectedGroup: String?
    let onRenameGroup: (String) -> Void
    let onDeleteGroup: (String) -> Void
    let onMove: (Snippet, String) -> Void

    private var groupNames: [String] {
        Array(Set(snippets.map(\.groupName))).sorted()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let defaultGroupName = NSLocalizedString("默认", comment: "")
                chip(nil, label: NSLocalizedString("全部分组", comment: ""), count: snippets.count)

                ForEach(groupNames, id: \.self) { name in
                    let count = snippets.filter { $0.groupName == name }.count
                    chip(name, label: name, count: count)
                        .dropDestination(for: String.self) { ids, _ in
                            guard let idString = ids.first,
                                  let snippet = snippets.first(where: { $0.id.uuidString == idString }) else { return false }
                            onMove(snippet, name)
                            return true
                        }
                        .contextMenu {
                            if name != defaultGroupName {
                                Button("重命名分组") {
                                    onRenameGroup(name)
                                }
                                Button("删除分组") {
                                    onDeleteGroup(name)
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ group: String?, label: String, count: Int) -> some View {
        Button {
            selectedGroup = group
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(selectedGroup == group ? Color.accentColor.opacity(0.25) : Color(nsColor: .quaternaryLabelColor).opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }
}
