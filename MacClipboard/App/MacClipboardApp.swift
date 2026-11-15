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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var container: ModelContainer?
    var monitor: ClipboardMonitor?
    var statusBarManager: StatusBarManager?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let modelContainer = try buildModelContainer()
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

            registerURLSchemeHandler()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    /// iCloud 同步开启时尝试 CloudKit 容器，失败（未登录/无授权）自动回退本地
    private func buildModelContainer() throws -> ModelContainer {
        if AppSettings.shared.iCloudSync {
            do {
                let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
                let container = try ModelContainer(
                    for: ClipboardItem.self, Snippet.self,
                    configurations: cloudConfig
                )
                print("SwiftData 容器：iCloud 同步已启用")
                return container
            } catch {
                print("iCloud 容器创建失败，回退本地存储: \(error)")
            }
        }
        return try ModelContainer(for: ClipboardItem.self, Snippet.self)
    }

    // MARK: - URL Scheme (macclipboard://)

    private func registerURLSchemeHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let direct = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
              let urlString = direct.stringValue,
              let url = URL(string: urlString),
              let command = URLCommand.parse(url) else { return }

        switch command {
        case .show:
            statusBarManager?.togglePanel()
        case .toggleIncognito:
            monitor?.isIncognito.toggle()
        case .paste(let index):
            pasteNthHistoryItem(index)
        }
    }

    private func pasteNthHistoryItem(_ index: Int) {
        guard let container, let modelContext = try? ModelContext(container) else { return }
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = index
        guard let items = try? modelContext.fetch(descriptor), items.count >= index else { return }
        AutoPaster.paste(item: items[index - 1])
        SoundManager.playPasteSound()
    }

    @MainActor
    func openSettingsWindow() {
        // 延时 80ms 避开 Popover 异步 performClose 导致的系统焦点回退问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self else { return }
            if self.settingsWindow == nil {
                let settingsView = SettingsView()
                    .modelContainer(self.container!)
                let hostingController = NSHostingController(rootView: settingsView)
                
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.center()
                window.title = NSLocalizedString("MacClipboard 偏好设置", comment: "")
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
