//
//  CustomCommandTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
@testable import MacClipboard

final class CustomCommandTests: XCTestCase {

    func testSimpleTransform() {
        let output = CustomCommand.run(command: "tr a-z A-Z", on: "hello world")
        XCTAssertEqual(output, "HELLO WORLD")
    }

    func testPipesAndFilters() {
        let output = CustomCommand.run(command: "grep 1 | head -2", on: "a1\nb2\na1x\nc3")
        XCTAssertEqual(output, "a1\na1x")
    }

    func testEmptyCommandReturnsNil() {
        XCTAssertNil(CustomCommand.run(command: "  ", on: "text"))
        XCTAssertNil(CustomCommand.run(command: "", on: "text"))
    }

    func testFailingCommandReturnsNil() {
        XCTAssertNil(CustomCommand.run(command: "false", on: "text"))
        XCTAssertNil(CustomCommand.run(command: "exit 3", on: "text"))
    }

    func testNoOutputReturnsNil() {
        XCTAssertNil(CustomCommand.run(command: "cat > /dev/null", on: "text"))
    }
}
