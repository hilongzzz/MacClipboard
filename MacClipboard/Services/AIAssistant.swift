//
//  AIAssistant.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import AppKit
import SwiftUI
import FoundationModels

/// Apple Intelligence 端上模型动作（macOS 26+）：
/// 对选中文本卡片执行摘要 / 翻译 / 润色，结果在独立窗口展示。
enum AIAssistant {

    enum Action: String, CaseIterable {
        case summarize
        case translate
        case polish
    }

    static var isAvailable: Bool {
        guard #available(macOS 26.0, *) else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func run(action: Action, text: String) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw NSError(domain: "AIAssistant", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "需要 macOS 26 及以上版本"])
        }
        let prompt: String
        switch action {
        case .summarize:
            prompt = "请用简洁的中文总结以下内容，只输出总结结果：\n\n\(text)"
        case .translate:
            prompt = "请翻译以下内容（中文译为英文，其他语言译为中文），只输出译文：\n\n\(text)"
        case .polish:
            prompt = "请润色以下文字，保持原意与语言，只输出润色后的结果：\n\n\(text)"
        }
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }

    /// 执行动作并展示结果窗口（右键菜单入口）
    @MainActor
    static func performAndShow(action: Action, text: String) {
        Task {
            do {
                let result = try await run(action: action, text: text)
                AIResultPresenter.show(title: NSLocalizedString(action.titleKey, comment: ""), text: result)
            } catch {
                NSSound.beep()
                print("AI 动作失败: \(error)")
            }
        }
    }
}

extension AIAssistant.Action {
    var titleKey: String {
        switch self {
        case .summarize: return "AI 摘要"
        case .translate: return "AI 翻译"
        case .polish: return "AI 润色"
        }
    }
}

/// AI 结果展示窗口（文本可选中复制）
@MainActor
enum AIResultPresenter {
    private static var window: NSWindow?

    static func show(title: String, text: String) {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            window = w
        }
        window?.title = title
        window?.contentView = NSHostingView(rootView: AIResultView(text: text))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AIResultView: View {
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            HStack {
                Spacer()
                Button(copied ? NSLocalizedString("已复制", comment: "") : NSLocalizedString("复制结果", comment: "")) {
                    QuickActions.copyText(text)
                    copied = true
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}
