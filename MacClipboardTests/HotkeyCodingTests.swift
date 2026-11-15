//
//  HotkeyCodingTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
import Carbon.HIToolbox
@testable import MacClipboard

final class HotkeyCodingTests: XCTestCase {

    private let cmd = Int(NSEvent.ModifierFlags.command.rawValue)
    private let shift = Int(NSEvent.ModifierFlags.shift.rawValue)
    private let option = Int(NSEvent.ModifierFlags.option.rawValue)
    private let control = Int(NSEvent.ModifierFlags.control.rawValue)
    private let capsLock = Int(NSEvent.ModifierFlags.capsLock.rawValue)

    func testCarbonModifiersMapping() {
        XCTAssertEqual(HotkeyCoding.carbonModifiers(from: option | shift), optionKey | shiftKey)
        XCTAssertEqual(HotkeyCoding.carbonModifiers(from: cmd | option), cmdKey | optionKey)
        XCTAssertEqual(HotkeyCoding.carbonModifiers(from: control), controlKey)
        XCTAssertEqual(HotkeyCoding.carbonModifiers(from: 0), 0)
        // 无关标志位（如 capsLock）应被忽略
        XCTAssertEqual(HotkeyCoding.carbonModifiers(from: option | capsLock), optionKey)
    }

    func testRequiresModifier() {
        XCTAssertTrue(HotkeyCoding.requiresModifier(option))
        XCTAssertTrue(HotkeyCoding.requiresModifier(cmd | shift))
        XCTAssertFalse(HotkeyCoding.requiresModifier(0))
        // 仅 capsLock 不足以构成合法热键
        XCTAssertFalse(HotkeyCoding.requiresModifier(capsLock))
    }

    func testDisplayString() {
        XCTAssertEqual(HotkeyCoding.displayString(modifiers: optionKey | shiftKey, display: "V"), "⌥⇧V")
        XCTAssertEqual(HotkeyCoding.displayString(modifiers: cmdKey, display: "C"), "⌘C")
        XCTAssertEqual(HotkeyCoding.displayString(modifiers: controlKey | optionKey, display: "A"), "⌃⌥A")
        XCTAssertEqual(HotkeyCoding.displayString(modifiers: 0, display: "F5"), "F5")
    }
}
