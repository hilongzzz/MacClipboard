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

    // 将内容写回剪切板并触发生效 Cmd + V
    static func paste(item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        let pastePlaintextOnly = AppSettings.shared.pastePlaintextOnly
        
        switch item.type {
        case .rtf:
            if !pastePlaintextOnly, let rtfData = item.rtfData {
                pb.setData(rtfData, forType: .rtf)
            }
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
        case .color, .url, .text:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        }
        
        if AppSettings.shared.autoPasteAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                simulateCmdV()
            }
        }
    }

    private static func simulateCmdV() {
        guard checkAccessibilityPermission(prompt: true) else {
            promptForAccessibilityPermission()
            return
        }
        
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func promptForAccessibilityPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "MacClipboard 需要辅助功能权限以自动触发 Cmd+V 粘贴。请在【系统设置 -> 隐私与安全性 -> 辅助功能】中允许 MacClipboard。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
