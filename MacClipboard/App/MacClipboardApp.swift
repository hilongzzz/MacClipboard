//
//  MacClipboardApp.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData
import os

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
        // 双实例防护：已有实例在跑时激活它并退出当前进程。
        // XCTest 宿主进程除外——否则单元测试会误判并中途杀掉测试宿主
        let environment = ProcessInfo.processInfo.environment
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil

        if !isRunningTests {
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if instances.count > 1,
               let existing = instances.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
                print("检测到已有实例 (pid=\(existing.processIdentifier))，激活它并退出当前进程")
                existing.activate(options: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NSApp.terminate(nil)
                }
                return
            }
        }

        let launchLog = Logger(subsystem: "com.yunlongzhang.MacClipboard", category: "launch")
        let preferredLocales = Bundle.main.preferredLocalizations
        print("Preferred localizations: \(preferredLocales)")
        launchLog.info("Launched. Preferred localizations: \(preferredLocales, privacy: .public)")

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
                },
                onDismiss: { [weak self] in
                    self?.statusBarManager?.dismissPanel()
                }
            )

            registerURLSchemeHandler()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    /// 退出时按设置清空未置顶历史（clear-on-quit）
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppSettings.shared.clearOnQuit, let container = container {
            HistoryStore(modelContext: container.mainContext).clearUnpinned()
        }
        return .terminateNow
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
        case .stats:
            logDebugStats()
        case .dump:
            dumpRecentHistory()
        }
    }

    /// 调试观测：历史/片段统计 + 最近条目摘要（stdout 与统一日志双通道）
    private let debugLog = Logger(subsystem: "com.yunlongzhang.MacClipboard", category: "debug")

    private func logDebugStats() {
        guard let container, let context = try? ModelContext(container) else {
            print("STATS container unavailable")
            return
        }
        let historyCount = (try? context.fetchCount(FetchDescriptor<ClipboardItem>())) ?? -1
        let snippetCount = (try? context.fetchCount(FetchDescriptor<Snippet>())) ?? -1
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let last = (try? context.fetch(descriptor))?.first
        let lastSummary = last.map {
            "\($0.typeRaw)|\(($0.textContent ?? "-").prefix(40))|pinned=\($0.isPinned)"
        } ?? "empty"
        let line = "STATS history=\(historyCount) snippets=\(snippetCount) incognito=\(monitor?.isIncognito ?? false) last=[\(lastSummary)]"
        print(line)
        debugLog.info("\(line)")
    }

    private func dumpRecentHistory() {
        guard let container, let context = try? ModelContext(container) else { return }
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let items = (try? context.fetch(descriptor)) ?? []
        print("DUMP begin")
        debugLog.info("DUMP begin")
        for (i, item) in items.enumerated() {
            let summary = String((item.textContent ?? "-").prefix(60))
            let hash = String((item.contentHash ?? "-").prefix(8))
            let dumpLine = "DUMP[\(i)] \(item.typeRaw) | \(summary) | pinned=\(item.isPinned) | hash=\(hash)"
            print(dumpLine)
            debugLog.info("\(dumpLine)")
        }
        print("DUMP end")
        debugLog.info("DUMP end")
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
