//
//  AppTheme.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import SwiftUI

/// 主题色预设：跟随系统或指定色彩，作用于面板、卡片选中态与设置页。
enum AppTheme {
    static let presets = ["system", "blue", "purple", "pink", "orange", "green"]

    static func tint(for name: String) -> Color? {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "orange": return .orange
        case "green": return .green
        default: return nil // system
        }
    }

    static func displayName(for name: String) -> String {
        NSLocalizedString("主题色-" + name, comment: "")
    }
}

extension View {
    /// 按设置应用主题色（system 时不覆盖系统强调色）
    @ViewBuilder
    func appAccentTint(_ name: String) -> some View {
        if let tint = AppTheme.tint(for: name) {
            self.tint(tint)
        } else {
            self
        }
    }

    /// macOS 26 Liquid Glass 玻璃材质；低版本自动降级为原样式
    @ViewBuilder
    func liquidGlass(in shape: some Shape) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self
        }
    }
}
