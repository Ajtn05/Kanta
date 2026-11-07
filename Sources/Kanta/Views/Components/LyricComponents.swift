import SwiftUI

extension LyricAlignment {
    var text: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frame: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

extension Highlight {
    func color(dark: Bool) -> Color {
        switch self {
        case .primary: return .primary
        case .mint: return dark ? Color(red: 0.66, green: 0.93, blue: 0.82) : Color(red: 0.00, green: 0.34, blue: 0.27)
        case .peach: return dark ? Color(red: 1, green: 0.77, blue: 0.62) : Color(red: 0.52, green: 0.22, blue: 0.11)
        case .lilac: return dark ? Color(red: 0.84, green: 0.75, blue: 1) : Color(red: 0.32, green: 0.21, blue: 0.60)
        }
    }
}

struct LyricTimeline<Content: View>: View {
    let playback: Playback?
    let lyrics: Lyrics
    let offset: Double
    @ViewBuilder let content: (Int?) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: playback?.state != .playing || !lyrics.synchronized)) { _ in
            content(lyrics.activeIndex(at: playback?.position() ?? 0, offset: offset))
        }
    }
}

struct LyricPreview: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var preferences: Preferences
    var maxLines: Int
    var compact = false
    var wrapsSingleLine = true
    var fittingSize: CGSize?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var options: SettingsValues { preferences.values }

    var body: some View {
        if let lyrics = model.lyrics.lyrics, !lyrics.instrumental, !lyrics.lines.isEmpty {
            let offset = preferences.offset(for: model.track)
            LyricTimeline(playback: model.playback, lyrics: lyrics, offset: offset) { current in
                if let fittingSize {
                    let rows = LyricPreviewSizing.rows(texts: lyrics.lines.map(\.text), current: current,
                        synchronized: lyrics.synchronized, size: fittingSize,
                        fontSize: options.lyricSize, spacing: options.lyricSpacing)
                    if LyricPreviewSizing.totalHeight(rows, spacing: options.lyricSpacing) > fittingSize.height {
                        // An unusually long line can wrap at the minimum font size without losing text.
                        ScrollView { fittedRows(rows, lyrics: lyrics, current: current, offset: offset) }
                            .frame(height: fittingSize.height)
                    } else {
                        fittedRows(rows, lyrics: lyrics, current: current, offset: offset)
                    }
                } else {
                    let indexes = visibleIndexes(current: current, count: lyrics.lines.count, synced: lyrics.synchronized)
                    VStack(spacing: options.lyricSpacing) {
                        if lyrics.synchronized && current == nil && maxLines == 1 {
                            placeholder("Waiting for the first line", icon: "ellipsis")
                        }
                        ForEach(indexes, id: \.self) { index in
                            let line = lyrics.lines[index]
                            let active = index == current || !lyrics.synchronized
                            let text = line.text.isEmpty ? "♪" : line.text
                            let label = Text(text)
                                .font(.system(size: fontSize(active: active), weight: active ? .semibold : .medium))
                                .foregroundStyle(active ? options.highlight.color(dark: scheme == .dark) : .secondary)
                                .multilineTextAlignment(options.lyricAlignment.text)
                                .lineLimit(maxLines == 1 && wrapsSingleLine ? 2 : 1)
                                .minimumScaleFactor(compact ? 0.8 : 1)
                                .frame(maxWidth: .infinity, alignment: options.lyricAlignment.frame)
                            if options.seekOnLyricClick, let time = lyrics.seekPosition(for: line, offset: offset) {
                                Button { model.send(.seek(time)) } label: { label.contentShape(Rectangle()) }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(line.text.isEmpty ? "Instrumental passage" : text)
                                    .accessibilityAddTraits(active ? .isSelected : [])
                                    .help("Seek to this line")
                                    .transition(.opacity)
                            } else {
                                label.accessibilityAddTraits(active ? .isSelected : [])
                                    .transition(.opacity)
                            }
                        }
                    }
                    .animation(options.animate && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: current)
                }
            }
        } else {
            placeholder(model.lyrics.message, icon: "music.note")
        }
    }

    private func fittedRows(_ rows: [LyricPreviewSizing.Row], lyrics: Lyrics,
                            current: Int?, offset: Double) -> some View {
        VStack(spacing: options.lyricSpacing) {
            ForEach(rows) { row in
                let line = lyrics.lines[row.id]
                let active = row.id == current || !lyrics.synchronized
                let text = line.text.isEmpty ? "♪" : line.text
                let label = Text(text)
                    .font(.system(size: row.fontSize, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? options.highlight.color(dark: scheme == .dark) : .secondary)
                    .multilineTextAlignment(options.lyricAlignment.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: options.lyricAlignment.frame)
                    .frame(height: row.height)
                    .contentShape(Rectangle())
                if options.seekOnLyricClick, let time = lyrics.seekPosition(for: line, offset: offset) {
                    Button { model.send(.seek(time)) } label: { label }
                        .buttonStyle(.plain)
                        .accessibilityLabel(line.text.isEmpty ? "Instrumental passage" : text)
                        .accessibilityAddTraits(active ? .isSelected : [])
                        .help("Seek to this line")
                } else {
                    label.accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
        .animation(options.animate && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: current)
    }

    private func visibleIndexes(current: Int?, count: Int, synced: Bool) -> Range<Int> {
        let limit = min(count, max(1, maxLines))
        if !synced { return 0..<limit }
        if current == nil && limit == 1 { return 0..<0 }
        let start = min(max(0, (current ?? 0) - limit / 2), max(0, count - limit))
        return start..<(start + limit)
    }

    private func fontSize(active: Bool) -> CGFloat {
        let size = compact ? min(18, options.lyricSize) : options.lyricSize
        return active ? size : max(11, size * 0.72)
    }

    private func placeholder(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(options.lyricAlignment.text)
            .lineLimit(wrapsSingleLine ? 2 : 1)
            .frame(maxWidth: .infinity, alignment: options.lyricAlignment.frame)
    }
}
