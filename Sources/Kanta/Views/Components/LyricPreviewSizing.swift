import AppKit

/// Measures complete lyric rows, shrinking to readable type before wrapping long lines.
enum LyricPreviewSizing {
    static let minimumFontSize: CGFloat = 11

    struct Row: Identifiable {
        let id: Int
        let fontSize: CGFloat
        let height: CGFloat
    }

    static func rows(texts: [String], current: Int?, synchronized: Bool,
                     size: CGSize, fontSize: CGFloat, spacing: CGFloat) -> [Row] {
        guard !texts.isEmpty else { return [] }
        let width = max(1, size.width)
        let height = max(1, size.height)
        let gap = max(0, spacing)
        let minimumHeight = lineHeight(fontSize: minimumFontSize)
        let capacity = min(texts.count, max(1, Int((height + gap) / (minimumHeight + gap))))
        var fitted: [Row] = []
        for count in 1...capacity {
            let start = synchronized
                ? min(max(0, (current ?? 0) - count / 2), texts.count - count) : 0
            let candidate = (start..<(start + count)).map { index in
                let active = !synchronized || index == current
                let preferred = max(minimumFontSize, active ? fontSize : fontSize * 0.72)
                let weight: NSFont.Weight = active ? .semibold : .medium
                let text = texts[index].isEmpty ? "♪" : texts[index]
                let pointSize = fittedFontSize(text: text, preferred: preferred, weight: weight, width: width)
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: max(1, width - 4), height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: NSFont.systemFont(ofSize: pointSize, weight: weight)])
                return Row(id: index, fontSize: pointSize,
                           height: max(lineHeight(fontSize: pointSize), ceil(bounds.height) + 2))
            }
            let usedHeight = totalHeight(candidate, spacing: gap)
            if count > 1 && usedHeight > height { break }
            fitted = candidate
            if usedHeight > height { break }
        }
        return fitted
    }

    static func totalHeight(_ rows: [Row], spacing: CGFloat) -> CGFloat {
        rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * max(0, spacing)
    }

    private static func fittedFontSize(text: String, preferred: CGFloat,
                                      weight: NSFont.Weight, width: CGFloat) -> CGFloat {
        func measuredWidth(_ size: CGFloat) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
        }
        // Optical sizing changes glyph proportions, so width does not scale linearly with point size.
        let available = max(1, width - 4)
        if measuredWidth(preferred) <= available { return preferred }
        var lower = minimumFontSize
        var upper = preferred
        for _ in 0..<10 {
            let middle = (lower + upper) / 2
            if measuredWidth(middle) <= available { lower = middle } else { upper = middle }
        }
        return lower
    }

    private static func lineHeight(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        return ceil(font.ascender - font.descender + font.leading) + 2
    }
}
