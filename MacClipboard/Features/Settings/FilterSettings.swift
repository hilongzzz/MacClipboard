//
//  FilterSettings
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

struct IgnoreSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("录制类型") {
                Toggle("记录文本与链接", isOn: $settings.recordText)
                Toggle("记录图片", isOn: $settings.recordImages)
                Toggle("记录文件", isOn: $settings.recordFiles)
                Toggle("图片 OCR 文字识别", isOn: $settings.imageOCR)
            }

            Section("应用黑名单 (Bundle ID，逗号分隔)") {
                TextField("例如: com.apple.Terminal, com.googlecode.iterm2", text: $settings.customExcludedBundleIDs, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("正则表达式敏感字段屏蔽 (每行一条)") {
                TextField("正则匹配表达式", text: $settings.sensitiveRegexPatterns, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .formStyle(.grouped)
    }
}
