//
//  URLScheme.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import Foundation

/// macclipboard:// URL 命令解析：
/// - macclipboard://show            打开面板
/// - macclipboard://toggle-incognito 切换无痕
/// - macclipboard://paste?n=3       粘贴第 3 条历史
enum URLCommand: Equatable {
    case show
    case toggleIncognito
    case paste(index: Int)

    static func parse(_ url: URL) -> URLCommand? {
        guard url.scheme?.lowercased() == "macclipboard" else { return nil }
        switch url.host?.lowercased() ?? "" {
        case "show":
            return .show
        case "toggle-incognito":
            return .toggleIncognito
        case "paste":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let n = components?.queryItems?.first { $0.name == "n" }
                .flatMap { Int($0.value ?? "") } ?? 1
            return .paste(index: max(1, n))
        default:
            return nil
        }
    }
}
