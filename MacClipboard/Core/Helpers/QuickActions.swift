//
//  QuickActions.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import AppKit

/// 右键菜单的快速操作：打开链接、Finder 定位、网页搜索、颜色格式转换。
enum QuickActions {

    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func searchWeb(_ text: String) {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }

    static func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - HEX → RGB / HSL

    /// 解析 HEX 为 0-255 分量，支持 3/6/8 位
    static func rgbComponents(fromHex hex: String) -> (r: Int, g: Int, b: Int)? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
        switch cleaned.count {
        case 6:
            return (Int(int >> 16 & 0xFF), Int(int >> 8 & 0xFF), Int(int & 0xFF))
        case 8:
            return (Int(int >> 24 & 0xFF), Int(int >> 16 & 0xFF), Int(int >> 8 & 0xFF))
        case 3:
            return (Int(int >> 8 & 0xF) * 17, Int(int >> 4 & 0xF) * 17, Int(int & 0xF) * 17)
        default:
            return nil
        }
    }

    static func rgbString(fromHex hex: String) -> String? {
        guard let c = rgbComponents(fromHex: hex) else { return nil }
        return "rgb(\(c.r), \(c.g), \(c.b))"
    }

    static func hslString(fromHex hex: String) -> String? {
        guard let c = rgbComponents(fromHex: hex) else { return nil }
        let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
        let maxValue = max(r, g, b), minValue = min(r, g, b)
        let delta = maxValue - minValue

        var hue: Double = 0
        if delta > 0 {
            switch maxValue {
            case r: hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g: hue = (b - r) / delta + 2
            default: hue = (r - g) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        let lightness = (maxValue + minValue) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        return "hsl(\(Int(hue.rounded())), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)"
    }
}
