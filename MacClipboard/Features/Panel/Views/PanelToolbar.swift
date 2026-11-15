//
//  PanelToolbar.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/16.
//

import SwiftUI

/// 面板顶栏：搜索框、无痕模式开关与设置入口
struct PanelToolbar: View {
    @Binding var searchText: String
    @Binding var isIncognito: Bool
    @FocusState.Binding var isSearchFocused: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("搜索剪切板 (⌥⇧V)...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            Toggle(isOn: $isIncognito) {
                Image(systemName: isIncognito ? "eye.slash.fill" : "eye")
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
    }
}
