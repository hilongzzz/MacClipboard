//
//  StatusBarManager.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import AppKit
import SwiftUI
import SwiftData
import Combine

@MainActor
final class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitor: ClipboardMonitor
    private var onOpenSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(container: ModelContainer, monitor: ClipboardMonitor, onOpenSettings: @escaping () -> Void) {
        self.monitor = monitor
        self.onOpenSettings = onOpenSettings
        super.init()
        
        // 1. 初始化 MenuBar 图标（自动适配浅色/深色主题）
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clipboard")
            image?.isTemplate = true // 关键：自动根据系统顶部栏颜色适配黑白反转
            button.image = image
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 订阅无痕模式状态以实时切换状态栏图标
        monitor.$isIncognito
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isIncognito in
                self?.updateStatusIcon(isIncognito: isIncognito)
            }
            .store(in: &cancellables)

        // 2. 初始化 Popover 视图，并将 onOpenSettings 回调透传给 MenuBarView
        let popoverView = MenuBarView(
            monitor: monitor,
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil) // 打开设置时自动收起状态栏弹窗
                onOpenSettings()
            }
        )
        .modelContainer(container)
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.behavior = .transient // 点击弹窗外部区域自动隐藏
        popover.contentViewController = NSHostingController(rootView: popoverView)

        // 3. 注册全局快捷键监听 (Option + Shift + V)
        registerGlobalHotkey()
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            if popover.isShown {
                popover.performClose(nil)
            }
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 激活 App 确保 Popover 内部的 TextField 能直接获得键盘输入焦点
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "唤出剪贴板 (⌥⇧V)", action: #selector(togglePopover), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let incognitoItem = NSMenuItem(title: "无痕模式", action: #selector(toggleIncognito), keyEquivalent: "")
        incognitoItem.target = self
        incognitoItem.state = monitor.isIncognito ? .on : .off
        menu.addItem(incognitoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "偏好设置...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 MacClipboard", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func toggleIncognito() {
        monitor.isIncognito.toggle()
    }

    @objc func openSettingsFromMenu() {
        onOpenSettings()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateStatusIcon(isIncognito: Bool) {
        if let button = statusItem.button {
            let systemName = isIncognito ? "eye.slash" : "paperclip"
            let image = NSImage(systemSymbolName: systemName, accessibilityDescription: "Clipboard")
            image?.isTemplate = true
            button.image = image
        }
    }

    private func registerGlobalHotkey() {
        // 监听全局键盘按键按下事件
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Option (4096) + Shift (131072) + 'V' (keyCode 9)
            if flags == [.option, .shift] && event.keyCode == 9 {
                Task { @MainActor in
                    self?.togglePopover()
                }
            }
        }
    }
}
