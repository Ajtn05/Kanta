import SwiftUI

struct CompactPlayer: View {
    @ObservedObject var model: PlayerModel
    let settings: SettingsValues

    var body: some View {
        if let playback = model.playback {
            GeometryReader { geometry in
                let cover = min(66, max(42, geometry.size.height - 27))
                VStack(spacing: 1) {
                    HStack(spacing: 10) {
                        SleeveArtwork(artwork: model.artwork)
                            .frame(width: cover, height: cover)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            if geometry.size.width > 370 {
                                Eyebrow(title: playback.state == .paused ? "Paused" : playback.track.source.title,
                                        icon: playback.state == .paused ? "pause.fill" : "waveform")
                                    .foregroundStyle(.secondary)
                            }
                            if settings.showMetadata { TrackDetails(track: playback.track) }
                        }
                        Spacer(minLength: 0)
                        Transport(model: model, size: geometry.size.width > 370 ? 31 : 27)
                    }
                    if settings.showProgress {
                        ProgressStrip(playback: playback, seek: { model.send(.seek($0)) })
                    }
                }
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
