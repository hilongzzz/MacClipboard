//
//  MacClipboardApp.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

@main
struct MacClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var container: ModelContainer?
    var monitor: ClipboardMonitor?
    var statusBarManager: StatusBarManager?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let modelContainer = try ModelContainer(for: ClipboardItem.self)
            self.container = modelContainer

            let monitorInstance = ClipboardMonitor(modelContext: modelContainer.mainContext)
            self.monitor = monitorInstance

            self.statusBarManager = StatusBarManager(
                container: modelContainer,
                monitor: monitorInstance,
                onOpenSettings: { [weak self] in
                    self?.openSettingsWindow()
                }
            )

        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    @MainActor
    func openSettingsWindow() {
        // 延时 80ms 避开 Popover 异步 performClose 导致的系统焦点回退问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            if self.settingsWindow == nil {
                let settingsView = SettingsView()
                let hostingController = NSHostingController(rootView: settingsView)
                
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 540, height: 420),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                window.center()
                window.title = "MacClipboard 偏好设置"
                window.contentViewController = hostingController
                window.isReleasedWhenClosed = false
                self.settingsWindow = window
            }
            
            self.settingsWindow?.center()
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            self.settingsWindow?.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
