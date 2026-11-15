//
//  AppLanguage.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import Foundation

/// 应用内可选语言（原生名称展示，无需翻译）
enum AppLanguage {
    struct Entry {
        let code: String
        let nativeName: String
    }

    static let available: [Entry] = [
        .init(code: "zh-Hans", nativeName: "简体中文"),
        .init(code: "zh-Hant", nativeName: "繁體中文"),
        .init(code: "en", nativeName: "English"),
        .init(code: "ja", nativeName: "日本語"),
        .init(code: "ko", nativeName: "한국어"),
        .init(code: "fr", nativeName: "Français"),
        .init(code: "de", nativeName: "Deutsch"),
        .init(code: "es", nativeName: "Español"),
        .init(code: "pt-BR", nativeName: "Português (Brasil)"),
        .init(code: "ru", nativeName: "Русский"),
        .init(code: "it", nativeName: "Italiano")
    ]

    /// 写入 AppleLanguages 偏好；"system" 表示跟随系统（清除覆盖）
    static func apply(_ code: String) {
        let defaults = UserDefaults.standard
        if code == "system" {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
        defaults.synchronize()
    }
}
