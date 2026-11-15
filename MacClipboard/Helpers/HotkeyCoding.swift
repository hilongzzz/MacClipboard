//
//  HotkeyCoding.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit
import Carbon.HIToolbox

/// 全局热键的编码与显示：NSEvent 修饰键 ⇄ Carbon 掩码 ⇄ 展示文本。
enum HotkeyCoding {

    /// NSEvent.ModifierFlags.rawValue（或其子集）→ Carbon 修饰键掩码
    static func carbonModifiers(from flags: Int) -> Int {
        var carbon = 0
        if flags & Int(NSEvent.ModifierFlags.command.rawValue) != 0 { carbon |= cmdKey }
        if flags & Int(NSEvent.ModifierFlags.shift.rawValue) != 0 { carbon |= shiftKey }
        if flags & Int(NSEvent.ModifierFlags.option.rawValue) != 0 { carbon |= optionKey }
        if flags & Int(NSEvent.ModifierFlags.control.rawValue) != 0 { carbon |= controlKey }
        return carbon
    }

    /// 录制的快捷键必须至少包含一个功能修饰键（⌘/⇧/⌥/⌃），防止劫持普通按键
    static func requiresModifier(_ flags: Int) -> Bool {
        let meaningful = Int(
            NSEvent.ModifierFlags.command.rawValue
                | NSEvent.ModifierFlags.shift.rawValue
                | NSEvent.ModifierFlags.option.rawValue
                | NSEvent.ModifierFlags.control.rawValue
        )
        return flags & meaningful != 0
    }

    /// 组合展示文本，如 "⌥⇧V"
    static func displayString(modifiers: Int, display: String) -> String {
        var text = ""
        if modifiers & controlKey != 0 { text += "⌃" }
        if modifiers & optionKey != 0 { text += "⌥" }
        if modifiers & shiftKey != 0 { text += "⇧" }
        if modifiers & cmdKey != 0 { text += "⌘" }
        return text + display
    }
}
