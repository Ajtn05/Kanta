import Foundation

struct LyricLine: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let time: TimeInterval?
    let text: String
}

struct Lyrics: Codable, Equatable, Sendable {
    let lines: [LyricLine]
    var instrumental = false

    var synchronized: Bool { lines.first?.time != nil }

    func activeIndex(at position: TimeInterval, offset: TimeInterval) -> Int? {
        guard synchronized else { return nil }
        let target = position + offset
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if (lines[middle].time ?? .infinity) <= target {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower > 0 ? lower - 1 : nil
    }

    func seekPosition(for line: LyricLine, offset: TimeInterval) -> TimeInterval? {
        line.time.map { max(0, $0 - offset) }
    }
}

enum LRCParser {
    private static let timestamp = #/\[([0-9]{1,5}):([0-5]?[0-9])(?:[.:]([0-9]{1,3}))?\]/#
    private static let header = #/(?i)^\s*\[(?:al|ar|au|by|length|offset|re|ti|tool|ve):.*\]\s*$/#
    private static let offset = #/(?i)^\s*\[offset:\s*([+-]?[0-9]+)\s*\]\s*$/#
    private static let wordTiming = #/<[0-9]{1,5}:[0-5]?[0-9](?:[.:][0-9]{1,3})?>/#

    static func parse(_ text: String) -> Lyrics {
        var shift: TimeInterval = 0
        var timed: [(time: TimeInterval, text: String)] = []
        var plain: [String] = []
        let rows = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for row in rows {
            if let match = row.wholeMatch(of: offset), let milliseconds = Double(match.1), milliseconds.isFinite {
                shift = milliseconds / 1000
                continue
            }
            if row.wholeMatch(of: header) != nil { continue }

            var remaining = row.drop(while: \.isWhitespace)
            var times: [TimeInterval] = []
            while let match = remaining.prefixMatch(of: timestamp) {
                let minutes = Double(match.1) ?? 0
                let seconds = Double(match.2) ?? 0
                let fraction = match.3.flatMap { Double("0." + $0) } ?? 0
                times.append(minutes * 60 + seconds + fraction)
                remaining = remaining[match.range.upperBound...].drop(while: \.isWhitespace)
            }
            let value = remaining.replacing(wordTiming, with: "").trimmingCharacters(in: .whitespaces)
            if times.isEmpty {
                if !value.isEmpty { plain.append(value) }
            } else {
                timed.append(contentsOf: times.map { ($0, value) })
            }
        }

        guard !timed.isEmpty else {
            return Lyrics(lines: plain.enumerated().map { LyricLine(id: $0, time: nil, text: $1) })
        }

        // LRC's offset advances the displayed lyric when it is positive.
        let sorted = timed.sorted { $0.time < $1.time }
        var lines: [LyricLine] = []
        for item in sorted {
            let time = max(0, item.time - shift)
            if let last = lines.last, last.time == time {
                if !item.text.isEmpty && last.text != item.text {
                    let joined = last.text.isEmpty ? item.text : last.text + "\n" + item.text
                    lines[lines.count - 1] = LyricLine(id: last.id, time: time, text: joined)
                }
            } else {
                lines.append(LyricLine(id: lines.count, time: time, text: item.text))
            }
        }
        return Lyrics(lines: lines)
    }
}

enum LyricsStatus: Equatable {
    case idle, loading, available(Lyrics), missing, offline, failed

    var lyrics: Lyrics? {
        if case .available(let lyrics) = self { return lyrics }
        return nil
    }

    var message: String {
        switch self {
        case .idle: return "Lyrics appear when a song is playing."
        case .loading: return "Finding lyrics…"
        case .available(let lyrics): return lyrics.instrumental ? "Instrumental track" : ""
        case .missing: return "No matching lyrics. Search again or paste your own."
        case .offline: return "You’re offline. Cached and pasted lyrics are still available."
        case .failed: return "Lyrics couldn’t load. Try searching again."
        }
    }
}
