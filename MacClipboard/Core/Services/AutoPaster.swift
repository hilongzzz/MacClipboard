//
//  AutoPaster.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import AppKit
import ApplicationServices

struct AutoPaster {
    // 检查是否有辅助功能权限
    static func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// 仅写回剪贴板，不触发模拟按键（⌘C 快捷复制使用）
    static func copy(item: ClipboardItem) {
        writeToPasteboard(item)
    }

    /// 片段版本：仅写回剪贴板
    static func copy(snippet: Snippet) {
        writeSnippetToPasteboard(snippet)
    }

    /// 片段版本：写回剪贴板并按设置触发模拟 Cmd+V
    static func paste(snippet: Snippet, forcePlainText: Bool = false) {
        writeSnippetToPasteboard(snippet)

        if AppSettings.shared.autoPasteAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                simulateCmdV()
            }
        }
    }

    private static func writeSnippetToPasteboard(_ snippet: Snippet) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch snippet.type {
        case .image:
            if let data = snippet.plainImageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        default:
            if let text = snippet.textContent {
                pb.setString(text, forType: .string)
            }
        }
    }

    /// 写回剪贴板并按设置触发模拟 Cmd+V；forcePlainText 单次强制纯文本（Shift+点击）
    static func paste(item: ClipboardItem, forcePlainText: Bool = false) {
        writeToPasteboard(item, forcePlainText: forcePlainText)

        if AppSettings.shared.autoPasteAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                simulateCmdV()
            }
        }
    }

    private static func writeToPasteboard(_ item: ClipboardItem, forcePlainText: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let pastePlaintextOnly = AppSettings.shared.pastePlaintextOnly || forcePlainText

        switch item.type {
        case .rtf:
            if !pastePlaintextOnly, let rtfData = item.plainRTFData {
                pb.setData(rtfData, forType: .rtf)
            }
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let data = item.plainImageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .file:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) }
            if !urls.isEmpty {
                pb.writeObjects(urls as [NSURL])
            }
        case .color, .url, .text:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        }
    }

    private static func simulateCmdV() {
        guard checkAccessibilityPermission(prompt: true) else {
            promptForAccessibilityPermission()
            return
        }

        // 使用 hidSystemState 避免继承合并当前已按下的用户层硬件复合修饰键
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }

        // 严格锁定 flags 仅包含 Command，阻止物理 Shift / Option 串入造成误触
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func promptForAccessibilityPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("需要辅助功能权限", comment: "")
            alert.informativeText = NSLocalizedString(
                "MacClipboard 需要辅助功能权限以自动触发 Cmd+V 粘贴。请在【系统设置 -> 隐私与安全性 -> 辅助功能】中允许 MacClipboard。",
                comment: ""
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("打开系统设置", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
