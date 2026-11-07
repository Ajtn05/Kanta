import SwiftUI

/// Keeps the cover clear, with playback and lyrics controls in their own area below it.
struct AlbumPlayer: View {
    @ObservedObject var model: PlayerModel
    let settings: SettingsValues
    let fullLyrics: () -> Void

    var body: some View {
        if let playback = model.playback {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    SleeveArtwork(artwork: model.artwork, corner: 0)
                        .frame(width: side, height: side)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onTapGesture(count: 2, perform: fullLyrics)
                }
                Divider()
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        if settings.showMetadata {
                            TrackDetails(track: playback.track, size: 17)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer(minLength: 0)
                        }
                        Button(action: fullLyrics) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 30, height: 30)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Show Full Lyrics")
                        .accessibilityLabel("Show Full Lyrics")
                    }
                    if settings.showProgress {
                        ProgressStrip(playback: playback, seek: { model.send(.seek($0)) }, labels: true)
                    }
                    Transport(model: model, size: 34, featured: true)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(height: 160)
            }
        }
    }
}
