//
//  SensitiveFilterTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/8.
//

import XCTest
@testable import MacClipboard

final class SensitiveFilterTests: XCTestCase {

    func testConcealedTypes() {
        XCTAssertTrue(SensitiveFilter.isConcealed(["org.nspasteboard.ConcealedType"]))
        XCTAssertTrue(SensitiveFilter.isConcealed(["public.utf8-plain-text", "com.1password.concealed-type"]))
        XCTAssertFalse(SensitiveFilter.isConcealed(["public.utf8-plain-text", "public.html"]))
        XCTAssertFalse(SensitiveFilter.isConcealed([]))
    }

    func testDefaultCreditCardPattern() {
        // 注意：不能用 \b 边界——ICU 下 CJK 字符与数字相邻时不存在词边界，
        // 会导致「卡号4111…」漏检，因此默认正则使用 lookaround
        let pattern = "(?<!\\d)(?:\\d[ -]*?){13,16}(?!\\d)"
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("我的卡号 4111 1111 1111 1111 请查收", patternsString: pattern))
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("卡号4111111111111111", patternsString: pattern))
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("4111 1111 1111 1111", patternsString: pattern))
        // 17 位以上不是 13-16 位卡号
        XCTAssertFalse(SensitiveFilter.matchesSensitiveRegex("12345678901234567", patternsString: pattern))
        XCTAssertFalse(SensitiveFilter.matchesSensitiveRegex("今天天气不错", patternsString: pattern))
    }

    func testMultipleNewlineSeparatedPatterns() {
        let patterns = """
        id-card-pattern
        password-pattern
        """
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("password-pattern matched", patternsString: patterns))
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("id-card-pattern matched", patternsString: patterns))
        XCTAssertFalse(SensitiveFilter.matchesSensitiveRegex("nothing matched", patternsString: patterns))
    }

    func testPatternContainingCommaSurvives() {
        // 守护用例：正则本身含逗号（量词 {13,16}）时不能被分隔符误切
        let pattern = "(?<!\\d)(?:\\d[ -]*?){13,16}(?!\\d)"
        XCTAssertTrue(SensitiveFilter.matchesSensitiveRegex("卡号 4111 1111 1111 1111", patternsString: pattern))
    }

    func testWhitespaceOnlyPatternsIgnored() {
        XCTAssertFalse(SensitiveFilter.matchesSensitiveRegex("anything", patternsString: " \n \n "))
    }
}
