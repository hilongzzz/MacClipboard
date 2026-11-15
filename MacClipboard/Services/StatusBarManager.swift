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
    private var panel: NSPanel!
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
            // leftMouseDown：点击瞬间响应，避免窗口服务器激活切换吞掉第一次点击
            button.sendAction(on: [.leftMouseDown, .rightMouseUp])
        }

        // 订阅无痕模式状态以实时切换状态栏图标
        monitor.$isIncognito
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isIncognito in
                self?.updateStatusIcon(isIncognito: isIncognito)
            }
            .store(in: &cancellables)

        // 2. 面板视图（NSPanel：可调大小、尺寸自动记忆、失焦自动隐藏）
        let panelView = MenuBarView(
            monitor: monitor,
            onOpenSettings: { [weak self] in
                self?.panel.orderOut(nil) // 打开设置时自动收起面板
                onOpenSettings()
            }
        )
        .modelContainer(container)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true // 点击面板外部自动隐藏（等价原 popover transient）
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: panelView)
        panel.setFrameAutosaveName("MainPanel")

        // 3. 注册全局快捷键（可在设置中自定义）
        registerGlobalHotkey()

        // 4. 设置页调整面板尺寸后实时生效（仅在用户未手动改过尺寸时）
        NotificationCenter.default.addObserver(
            forName: AppSettings.appearanceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.applyPanelSizeIfNeeded()
            }
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            if panel.isVisible {
                panel.orderOut(nil)
            }
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    /// 显示/隐藏面板，并定位到状态栏图标下方（多显示器边界内）
    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }
        // 顺序很关键：先激活 App，面板才能成为 key（.nonactivatingPanel 特性），
        // 否则第一次点击时面板会被激活切换吞掉。
        // App 已激活后 makeKeyAndOrderFront 可带淡入动画（orderFrontRegardless 无动画）
        NSApp.activate(ignoringOtherApps: true)
        applyPanelSizeIfNeeded()
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)
    }

    private func applyPanelSizeIfNeeded() {
        // 用户手动调整过尺寸（autosave 已有记录）则尊重其尺寸
        guard UserDefaults.standard.object(forKey: "NSWindow Frame MainPanel") == nil else { return }
        switch AppSettings.shared.popoverSize {
        case "small": panel.setContentSize(NSSize(width: 320, height: 380))
        case "large": panel.setContentSize(NSSize(width: 460, height: 560))
        default: panel.setContentSize(NSSize(width: 380, height: 460))
        }
    }

    private func positionPanelBelowStatusItem() {
        // 可选：面板出现在鼠标所在的屏幕（多显示器场景）
        if AppSettings.shared.panelFollowsMouseScreen {
            let mouseLocation = NSEvent.mouseLocation
            if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                let visibleFrame = mouseScreen.visibleFrame
                let x = visibleFrame.midX - panel.frame.width / 2
                panel.setFrameTopLeftPoint(CGPoint(x: x, y: visibleFrame.maxY - 10))
                return
            }
        }

        guard let button = statusItem.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }
        let buttonRect = buttonWindow.convertToScreen(button.frame)
        let panelWidth = panel.frame.width

        let visibleFrame = screen.visibleFrame
        var x = buttonRect.midX - panelWidth / 2
        x = max(visibleFrame.minX + 8, min(x, visibleFrame.maxX - panelWidth - 8))
        let y = buttonRect.minY - 6
        panel.setFrameTopLeftPoint(CGPoint(x: x, y: y))
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let showItem = NSMenuItem(
            title: NSLocalizedString("唤出剪贴板 (⌥⇧V)", comment: ""),
            action: #selector(togglePanel),
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
                manager.togglePanel()
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
