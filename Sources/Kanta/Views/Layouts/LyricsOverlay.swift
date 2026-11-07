import SwiftUI

struct LyricsOverlay: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var preferences: Preferences
    @ViewState private var hovered = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let options = preferences.values
            // Keep padding and control space stable while hovering and resizing.
            let controlSpace = geometry.size.height >= 132 && options.lyricControls && !options.clickThrough
            let reveal = controlSpace && (hovered || options.showControls || voiceOver)
            let unsynced = options.showPlainLyrics && (model.lyrics.lyrics.map { !$0.synchronized && !$0.instrumental && !$0.lines.isEmpty } ?? false)
            let lyricSize = CGSize(width: max(1, geometry.size.width - 32),
                                   height: max(1, geometry.size.height - 24 - (controlSpace ? 31 : 0) - (unsynced ? 20 : 0)))
            VStack(spacing: 6) {
                if unsynced {
                    UnsyncedLyricsIndicator().frame(maxWidth: .infinity, alignment: .trailing)
                }
                if model.playback == nil {
                    Text(model.availability.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .help(model.availability.detail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LyricPreview(model: model, preferences: preferences, maxLines: .max,
                                 wrapsSingleLine: false, fittingSize: lyricSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if controlSpace {
                    Transport(model: model, size: 25)
                        .opacity(reveal ? 1 : 0)
                        .allowsHitTesting(reveal)
                        .accessibilityHidden(!reveal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: options.lyricOpacity < 0.3 ? .black.opacity(0.82) : .clear, radius: 2)
            .animation(options.animate && !reduceMotion ? .easeOut(duration: 0.17) : nil, value: reveal)
        }
        .onHover { hovered = $0 }
    }
}
