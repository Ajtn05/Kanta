import SwiftUI

struct CombinedPlayer: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var preferences: Preferences

    private var settings: SettingsValues { preferences.values }

    var body: some View {
        if let playback = model.playback {
            GeometryReader { geometry in
                let size = geometry.size
                let horizontal = settings.arrangement == .horizontal
                    || (settings.arrangement == .automatic && size.width >= 480)
                if horizontal {
                    let paneWidth = min(260, max(130, (size.width - 65) * 0.43))
                    HStack(spacing: 16) {
                        playerPane(playback, width: paneWidth, height: size.height - 32)
                            .frame(width: paneWidth)
                        Divider().padding(.vertical, 2)
                        lyrics(height: size.height - 32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 11) {
                        HStack(spacing: 10) {
                            SleeveArtwork(artwork: model.artwork)
                                .frame(width: 48, height: 48)
                            if settings.showMetadata {
                                TrackDetails(track: playback.track, size: 14, alignment: .center)
                                    .frame(maxWidth: .infinity)
                            }
                            Spacer(minLength: 0)
                            Transport(model: model, size: 26)
                        }
                        if settings.showProgress {
                            ProgressStrip(playback: playback, seek: { model.send(.seek($0)) })
                        }
                        Divider()
                        lyrics(height: size.height - 118)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(16)
                }
            }
        }
    }

    private func playerPane(_ playback: Playback, width: CGFloat, height: CGFloat) -> some View {
        let metadataSize: CGFloat = height > 230 ? 17 : 14
        let showAlbum = height > 280 && !playback.track.album.isEmpty
        let metadataHeight = settings.showMetadata ? metadataSize * (showAlbum ? 3.1 : 2.3) + 6 : 0
        let controlSize: CGFloat = height > 260 ? 32 : 28
        let progressHeight: CGFloat = settings.showProgress ? (height > 270 ? 26 : 13) : 0
        let gaps: CGFloat = 8 * (1 + (settings.showMetadata ? 1 : 0) + (settings.showProgress ? 1 : 0))
        let cover = min(width, max(60, height - metadataHeight - controlSize - progressHeight - gaps))
        return VStack(spacing: 8) {
            SleeveArtwork(artwork: model.artwork, corner: 10)
                .frame(width: cover, height: cover)
                .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
            if settings.showMetadata {
                TrackDetails(track: playback.track, size: metadataSize,
                             showAlbum: showAlbum, alignment: .center)
                    .frame(maxWidth: .infinity)
            }
            Transport(model: model, size: controlSize)
                .frame(maxWidth: .infinity)
            if settings.showProgress {
                ProgressStrip(playback: playback, seek: { model.send(.seek($0)) }, labels: height > 270)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func lyrics(height: CGFloat) -> some View {
        let rows = max(1, Int((height - 16) / (min(18, settings.lyricSize) + settings.lyricSpacing + 5)))
        return LyricPreview(model: model, preferences: preferences,
                            maxLines: min(rows, settings.lyricLines), compact: true)
    }
}
