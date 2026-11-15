//
//  HotkeyRecorder.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit
import SwiftUI

/// 点击后进入录制状态的快捷键录制按钮。
/// 按下新组合（须含 ⌘/⇧/⌥/⌃ 至少一个修饰键）即生效；Esc 取消。
final class HotkeyRecorderButton: NSButton {
    var isRecording = false
    var onUpdate: ((Int, Int, String) -> Void)? // modifiers, keyCode, display
    var displayProvider: (() -> String)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshTitle()
    }

    func refreshTitle() {
        if isRecording {
            title = NSLocalizedString("按下新快捷键…", comment: "")
        } else {
            title = displayProvider?() ?? ""
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }

        // Esc 取消录制
        if event.keyCode == 53 {
            isRecording = false
            refreshTitle()
            return
        }

        let flags = Int(event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)
        let carbonModifiers = HotkeyCoding.carbonModifiers(from: flags)
        guard HotkeyCoding.requiresModifier(flags), carbonModifiers != 0 else {
            NSSound.beep() // 必须带修饰键
            return
        }

        let display = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        onUpdate?(carbonModifiers, Int(event.keyCode), display)
        isRecording = false
        refreshTitle()
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    @ObservedObject var settings: AppSettings

    func makeNSView(context: Context) -> HotkeyRecorderButton {
        let button = HotkeyRecorderButton(frame: NSRect(x: 0, y: 0, width: 150, height: 28))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.displayProvider = { [weak button] in
            guard let button else { return "" }
            return HotkeyCoding.displayString(
                modifiers: AppSettings.shared.hotkeyModifiers,
                display: AppSettings.shared.hotkeyDisplay
            ) + (button.isRecording ? "" : "")
        }
        button.onUpdate = { modifiers, keyCode, display in
            let settings = AppSettings.shared
            settings.hotkeyModifiers = modifiers
            settings.hotkeyCode = keyCode
            settings.hotkeyDisplay = display
        }
        button.target = button
        button.action = #selector(HotkeyRecorderButton.clicked)
        return button
    }

    func updateNSView(_ button: HotkeyRecorderButton, context: Context) {
        button.refreshTitle()
    }
}

extension HotkeyRecorderButton {
    @objc func clicked() {
        isRecording.toggle()
        window?.makeFirstResponder(self)
        refreshTitle()
    }
}
