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
import Carbon.HIToolbox

@MainActor
final class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitor: ClipboardMonitor
    private var onOpenSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()

    // Carbon 全局热键句柄
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?

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

        // 3. 注册全局快捷键 (Option + Shift + V)
        // 使用 Carbon RegisterEventHotKey：应用自身聚焦时同样生效
        // （NSEvent.addGlobalMonitorForEvents 在本应用获得焦点时收不到事件）
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

        let showItem = NSMenuItem(
            title: NSLocalizedString("唤出剪贴板 (⌥⇧V)", comment: ""),
            action: #selector(togglePopover),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let incognitoItem = NSMenuItem(
            title: NSLocalizedString("无痕模式", comment: ""),
            action: #selector(toggleIncognito),
            keyEquivalent: ""
        )
        incognitoItem.target = self
        incognitoItem.state = monitor.isIncognito ? .on : .off
        menu.addItem(incognitoItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: NSLocalizedString("偏好设置...", comment: ""),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("退出 MacClipboard", comment: ""),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
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

    // MARK: - 全局热键（可在偏好设置中自定义）

    private func registerGlobalHotkey() {
        // 'MCLB' 签名，用于标识本应用注册的热键
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<StatusBarManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.togglePopover()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, context, &hotKeyEventHandler)
        reinstallHotkey()

        // 用户在设置页录制新热键后即时重注册
        NotificationCenter.default.addObserver(
            forName: AppSettings.hotkeyDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.reinstallHotkey()
            }
        }
    }

    private func reinstallHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        let settings = AppSettings.shared
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434C42), id: 1)
        RegisterEventHotKey(
            UInt32(settings.hotkeyCode),
            UInt32(settings.hotkeyModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
