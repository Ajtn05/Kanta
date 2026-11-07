import AppKit
import XCTest
@testable import Kanta

final class LyricPreviewSizingTests: XCTestCase {
    func testNarrowerWindowReducesTypeBeforeWrapping() throws {
        let text = "What if I told you that I've fallen?"
        let wide = try XCTUnwrap(LyricPreviewSizing.rows(texts: [text], current: 0, synchronized: true,
            size: CGSize(width: 700, height: 100), fontSize: 28, spacing: 5).first)
        let narrow = try XCTUnwrap(LyricPreviewSizing.rows(texts: [text], current: 0, synchronized: true,
            size: CGSize(width: 248, height: 100), fontSize: 28, spacing: 5).first)
        XCTAssertEqual(wide.fontSize, 28)
        XCTAssertLessThan(narrow.fontSize, wide.fontSize)
        XCTAssertGreaterThanOrEqual(narrow.fontSize, LyricPreviewSizing.minimumFontSize)
        let renderedWidth = (text as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: narrow.fontSize, weight: .semibold)
        ]).width
        XCTAssertLessThanOrEqual(renderedWidth, 248)
    }

    func testTallerWindowShowsMoreThanThreeRowsAndKeepsCurrentLine() {
        let texts = Array(repeating: "Still dancing on the water", count: 30)
        for current in [0, 15, 29] {
            let short = LyricPreviewSizing.rows(texts: texts, current: current, synchronized: true,
                size: CGSize(width: 368, height: 64), fontSize: 21, spacing: 5)
            let tall = LyricPreviewSizing.rows(texts: texts, current: current, synchronized: true,
                size: CGSize(width: 368, height: 300), fontSize: 21, spacing: 5)
            XCTAssertTrue(short.contains { $0.id == current })
            XCTAssertTrue(tall.contains { $0.id == current })
            XCTAssertGreaterThan(tall.count, max(3, short.count))
            XCTAssertLessThanOrEqual(LyricPreviewSizing.totalHeight(short, spacing: 5), 64)
            XCTAssertLessThanOrEqual(LyricPreviewSizing.totalHeight(tall, spacing: 5), 300)
        }
    }

    func testVeryLongLyricsWrapAtReadableMinimumInsteadOfTruncating() throws {
        let text = String(repeating: "We take the longer way home ", count: 12)
        let row = try XCTUnwrap(LyricPreviewSizing.rows(texts: [text], current: 0, synchronized: true,
            size: CGSize(width: 248, height: 64), fontSize: 36, spacing: 5).first)
        XCTAssertEqual(row.fontSize, LyricPreviewSizing.minimumFontSize)
        XCTAssertGreaterThan(row.height, 64) // The complete row is available in the overflow scroll view.
    }

    func testPlainLyricsAndLargeTypeRespectAvailableHeightAndSpacing() {
        let rows = LyricPreviewSizing.rows(texts: Array(repeating: "A quiet kind of light", count: 20),
            current: nil, synchronized: false, size: CGSize(width: 248, height: 200), fontSize: 36, spacing: 18)
        XCTAssertEqual(rows.map(\.id), Array(0..<rows.count))
        XCTAssertGreaterThan(rows.count, 1)
        XCTAssertLessThanOrEqual(LyricPreviewSizing.totalHeight(rows, spacing: 18), 200)
        XCTAssertTrue(LyricPreviewSizing.rows(texts: [], current: nil, synchronized: false,
            size: .zero, fontSize: 21, spacing: 5).isEmpty)
    }
}
