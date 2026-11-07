import SwiftUI

struct ArtworkPlayer: View {
    @ObservedObject var model: PlayerModel
    let settings: SettingsValues
    let expand: () -> Void
    @ViewState private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        if let playback = model.playback {
            let reveal = hovered || settings.showControls || voiceOver
            ZStack {
                SleeveArtwork(artwork: model.artwork, corner: 0)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: expand)
                Rectangle().fill(.black.opacity(reveal ? 0.34 : 0))
                    .allowsHitTesting(false)
                if reveal {
                    overlay(playback)
                        .transition(.opacity)
                } else if playback.state == .paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(8)
                        .background(.black.opacity(0.58), in: Circle())
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityLabel("Paused")
                        .allowsHitTesting(false)
                }
            }
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .onHover { hovered = $0 }
            .animation(settings.animate && !reduceMotion ? .easeOut(duration: 0.19) : nil, value: reveal)
        }
    }

    private func overlay(_ playback: Playback) -> some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.27), .clear, .black.opacity(0.82)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            Transport(model: model, size: 32, featured: true)
            VStack(alignment: .leading, spacing: 7) {
                Eyebrow(title: playback.track.source.title,
                        icon: playback.state == .paused ? "pause.fill" : "waveform")
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.48), in: Capsule())
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                if settings.showMetadata {
                    TrackDetails(track: playback.track, size: 16)
                        .allowsHitTesting(false)
                }
                if settings.showProgress {
                    ProgressStrip(playback: playback, seek: { model.send(.seek($0)) })
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
