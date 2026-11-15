//
//  ImageTextRecognizerTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
import AppKit
@testable import MacClipboard

final class ImageTextRecognizerTests: XCTestCase {

    /// 绘制一张含清晰文字的图片，验证 OCR 能提取出文本。
    /// Vision 快速识别具有概率性，允许最多 3 次尝试。
    func testRecognizeTextFromRenderedImage() async throws {
        let size = NSSize(width: 480, height: 120)
        let image = NSImage(size: size)
        image.lockFocusFlipped(false)
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 56, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        ("ABC 123" as NSString).draw(at: NSPoint(x: 40, y: 30), withAttributes: attributes)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return XCTFail("生成测试图片失败")
        }

        var lastResult: String?
        for _ in 0..<3 {
            lastResult = await ImageTextRecognizer.recognizeText(fromPNG: png)
            if let text = lastResult, text.contains("123") {
                return // 识别成功
            }
        }
        XCTFail("OCR 应识别出图片中的数字，实际: \(lastResult ?? "nil")")
    }

    func testInvalidDataReturnsNil() async {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        let text = await ImageTextRecognizer.recognizeText(fromPNG: garbage)
        XCTAssertNil(text)
    }
}
