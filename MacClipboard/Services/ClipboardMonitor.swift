//
//  ClipboardMonitor.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import AppKit
import Combine
import SwiftData

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published var isIncognito: Bool = false

    private var changeCount: Int
    private var timer: Timer?
    private var purgeTimer: Timer?
    private var store: HistoryStore

    init(modelContext: ModelContext) {
        self.store = HistoryStore(modelContext: modelContext)
        self.changeCount = NSPasteboard.general.changeCount
        startMonitoring()
        startPurgeScheduler()
    }

    /// 启动时清理一次 + 每小时巡检；设置页调整保留天数后立即清理
    private func startPurgeScheduler() {
        purgeExpiredHistory()
        purgeTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.purgeExpiredHistory()
            }
        }
        NotificationCenter.default.addObserver(
            forName: AppSettings.retentionDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.purgeExpiredHistory()
            }
        }
    }

    private func purgeExpiredHistory() {
        store.purgeExpired(olderThanDays: AppSettings.shared.historyRetentionDays)
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
    }

    private func checkPasteboard() {
        guard !isIncognito else { return }

        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        if let bundleID = frontmostApp?.bundleIdentifier, AppSettings.shared.excludedBundleIDSet.contains(bundleID) {
            return
        }

        let typeIdentifiers = pasteboard.types?.map { $0.rawValue } ?? []
        guard !SensitiveFilter.isConcealed(typeIdentifiers) else { return }

        // 文件承诺（file promise）：浏览器拖拽下载、导出面板等场景，
        // 粘贴板只有「承诺」而非真实路径，需要 NSFilePromiseReceiver 落盘后才能入库
        if AppSettings.shared.recordFiles,
           !Set(NSFilePromiseReceiver.readableDraggedTypes).intersection(typeIdentifiers).isEmpty {
            receivePromisedFiles(from: pasteboard, bundleID: frontmostApp?.bundleIdentifier)
            return
        }

        let snapshot = PasteboardSnapshot(
            typeIdentifiers: typeIdentifiers,
            rtfData: pasteboard.data(forType: .rtf),
            string: pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
            fileURLs: (pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL]) ?? [],
            hasImage: typeIdentifiers.contains(NSPasteboard.PasteboardType.tiff.rawValue)
                || typeIdentifiers.contains(NSPasteboard.PasteboardType.png.rawValue)
        )

        guard let classification = ClipboardClassifier.classify(snapshot) else { return }

        // 录制类型开关
        let settings = AppSettings.shared
        switch classification {
        case .rtf, .color, .url, .text:
            guard settings.recordText else { return }
        case .image:
            guard settings.recordImages else { return }
        case .file:
            guard settings.recordFiles else { return }
        }

        let bundleID = frontmostApp?.bundleIdentifier
        switch classification {
        case .rtf(let text, let rtfData):
            guard !matchesSensitiveRegex(text) else { return }
            storeItem(type: .rtf, textContent: text, plainRTF: rtfData, bundleID: bundleID)

        case .file(let paths, let displayName):
            guard !matchesSensitiveRegex(displayName) else { return }
            storeItem(type: .file, textContent: displayName, filePaths: paths, bundleID: bundleID)

        case .color(let text, let hex):
            guard !matchesSensitiveRegex(text) else { return }
            storeItem(type: .color, textContent: text, bundleID: bundleID, colorHex: hex)

        case .url(let text):
            guard !matchesSensitiveRegex(text) else { return }
            storeItem(type: .url, textContent: text, bundleID: bundleID, urlString: text)

        case .text(let text):
            guard !matchesSensitiveRegex(text) else { return }
            storeItem(type: .text, textContent: text, bundleID: bundleID)

        case .image:
            // TIFF 捕获必须在剪贴板被覆盖前完成（主线程），
            // 昂贵的 PNG 编码/缩略图/哈希全部移入后台队列
            guard let image = NSImage(pasteboard: pasteboard), let tiffData = image.tiffRepresentation else { return }
            Task.detached(priority: .userInitiated) { [weak self] in
                let bitmap = NSBitmapImageRep(data: tiffData)
                guard let pngData = bitmap?.representation(using: .png, properties: [:]) else { return }
                let thumbnailData = Self.makeThumbnailData(fromPNG: pngData, maxPixelSize: 240)
                await MainActor.run { [weak self] in
                    self?.storeItem(
                        type: .image,
                        plainImage: pngData,
                        plainThumbnail: thumbnailData,
                        bundleID: bundleID
                    )
                }
            }
        }
    }

    /// 把粘贴板中的文件承诺落盘到临时目录后入库
    private func receivePromisedFiles(from pasteboard: NSPasteboard, bundleID: String?) {
        let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)
            .intersection(pasteboard.types?.map { $0.rawValue } ?? [])
        guard let rawType = promiseTypes.first else { return }
        let receiverType = NSPasteboard.PasteboardType(rawType)
        guard let promiseList = pasteboard.data(forType: receiverType) else { return }
        guard let receiver = NSFilePromiseReceiver(pasteboardPropertyList: promiseList, ofType: receiverType) else { return }

        guard settingsAllowsFiles else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacClipboard-Promise-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let capturedBundleID = bundleID
        let queue = OperationQueue()
        receiver.receivePromisedFiles(
            atDestination: destination,
            options: [:],
            operationQueue: queue
        ) { [weak self] (fileURL: URL, error: Error?) in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let names = fileURL.lastPathComponent
                guard !SensitiveFilter.matchesSensitiveRegex(names, patternsString: AppSettings.shared.sensitiveRegexPatterns) else { return }
                self.storeItem(
                    type: .file,
                    textContent: names,
                    filePaths: [fileURL.path],
                    bundleID: capturedBundleID
                )
            }
        }
    }

    private var settingsAllowsFiles: Bool {
        AppSettings.shared.recordFiles
    }

    /// 生成列表展示用的缩略图，避免列表解码原始大图
    nonisolated private static func makeThumbnailData(fromPNG png: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    /// 统一入库入口：加密敏感数据、计算内容哈希，然后写入
    private func storeItem(
        type: ItemType,
        textContent: String? = nil,
        plainImage: Data? = nil,
        plainRTF: Data? = nil,
        plainThumbnail: Data? = nil,
        filePaths: [String]? = nil,
        bundleID: String?,
        colorHex: String? = nil,
        urlString: String? = nil
    ) {
        let item = ClipboardItem(
            type: type,
            textContent: textContent,
            imageData: plainImage.map(ContentCrypto.encrypt(data:)),
            rtfData: plainRTF.map(ContentCrypto.encrypt(data:)),
            colorHex: colorHex,
            urlString: urlString,
            sourceAppBundleID: bundleID,
            filePaths: filePaths,
            thumbnailData: plainThumbnail.map(ContentCrypto.encrypt(data:))
        )

        // 哈希基于明文计算，用于任意历史位置的去重
        switch type {
        case .image:
            item.contentHash = plainImage.map(ContentCrypto.hash(data:))
        case .rtf:
            item.contentHash = plainRTF.map(ContentCrypto.hash(data:)) ?? textContent.map(ContentCrypto.hash(text:))
        case .file:
            item.contentHash = ContentCrypto.hash(text: filePaths?.joined(separator: "\n") ?? "")
        case .text, .color, .url:
            item.contentHash = textContent.map(ContentCrypto.hash(text:))
        }

        if store.store(item, limit: AppSettings.shared.maxHistoryCount) == .inserted {
            SoundManager.playCopySound()
        }
    }

    private func matchesSensitiveRegex(_ text: String) -> Bool {
        SensitiveFilter.matchesSensitiveRegex(text, patternsString: AppSettings.shared.sensitiveRegexPatterns)
    }
}
