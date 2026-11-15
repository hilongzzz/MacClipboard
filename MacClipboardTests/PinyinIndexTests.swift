//
//  PinyinIndexTests.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import XCTest
@testable import MacClipboard

final class PinyinIndexTests: XCTestCase {

    func testChineseTextProducesFullPinyinAndInitials() {
        let index = PinyinIndex.index(for: "京东优惠券")
        XCTAssertNotNil(index)
        // CFStringTransform 按「字」输出音节，故为空格分词
        XCTAssertTrue(index!.contains("jing dong you hui quan"))
        // 紧凑全拼支持连续拼音查询
        XCTAssertTrue(index!.contains("jingdongyouhuiquan"))
        XCTAssertTrue(index!.contains("jdyhq"))
    }

    func testInitialsMatchQuery() {
        let index = PinyinIndex.index(for: "京东优惠券")!
        XCTAssertTrue(PinyinIndex.matches(text: "京东优惠券", pinyin: index, query: "jd"))
        XCTAssertTrue(PinyinIndex.matches(text: "京东优惠券", pinyin: index, query: "youhui"))
        XCTAssertTrue(PinyinIndex.matches(text: "京东优惠券", pinyin: index, query: "京东"))
    }

    func testMixedChineseEnglish() {
        let index = PinyinIndex.index(for: "北京的 Beijing")
        XCTAssertNotNil(index)
        XCTAssertTrue(index!.contains("beijing"))
        // 首字母串包含英文单词与拼音首字母
        XCTAssertTrue(index!.contains("bjd"))
    }

    func testPureEnglishReturnsNil() {
        XCTAssertNil(PinyinIndex.index(for: "plain english text"))
        XCTAssertNil(PinyinIndex.index(for: "123456"))
    }

    func testMatchesWithoutPinyin() {
        XCTAssertTrue(PinyinIndex.matches(text: "hello world", pinyin: nil, query: "wor"))
        XCTAssertFalse(PinyinIndex.matches(text: "hello", pinyin: nil, query: "xyz"))
        XCTAssertFalse(PinyinIndex.matches(text: "hello", pinyin: nil, query: ""))
    }
}
