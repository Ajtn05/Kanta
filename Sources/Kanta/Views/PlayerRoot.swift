import SwiftUI

struct PlayerRoot: View {
    let layout: PlayerLayout
    @ObservedObject var model: PlayerModel
    @ObservedObject var preferences: Preferences
    let select: (PlayerLayout) -> Void
    let fullLyrics: () -> Void
    let close: () -> Void
    let findLyrics: () -> Void
    let settings: () -> Void
    let move: (Bool) -> Void
    @ViewState private var hovered = false

    private var options: SettingsValues { preferences.values }

    var body: some View {
        let radius = options.cornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let opacity = layout == .lyrics ? options.lyricOpacity : options.backgroundOpacity
        ZStack {
            PlayerSurface(artwork: model.artwork, adaptive: options.adaptive, style: options.background, shape: shape)
                .opacity(opacity)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = model.commandError {
                Text(error)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .padding(8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .environment(\.colorScheme, layout == .lyrics && opacity < 0.3 ? .dark : resolvedScheme)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.primary.opacity(0.13 * opacity), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
        .modifier(PlayerWindowDrag(enabled: layout != .fullLyrics, move: move))
        .contextMenu {
            ForEach(PlayerLayout.miniPlayers) { mode in
                Button { select(mode) } label: { Label(mode.title, systemImage: mode.icon) }
            }
            Divider()
            Button("Show Full Lyrics", action: fullLyrics)
            Button("Find or Paste Lyrics…", action: findLyrics)
                .disabled(model.track == nil)
            Button(options.onTop ? "Use Normal Window Level" : "Keep Above Other Windows") {
                preferences.values.onTop.toggle()
            }
            if layout == .lyrics {
                Button("Enable Click-Through") { preferences.values.clickThrough = true }
            }
            Divider()
            Button("Preferences…", action: settings)
            Button("Hide Window", action: close)
        }
        .overlay(alignment: .bottomTrailing) {
            ResizeGrip()
                .stroke(.primary.opacity(hovered ? 0.45 : 0), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .frame(width: 10, height: 10)
                .padding(7)
                .contentShape(Rectangle())
                .help("Drag to resize")
                .accessibilityHidden(true)
        }
        .onHover { hovered = $0 }
    }

    @Environment(\.colorScheme) private var resolvedScheme

    @ViewBuilder private var content: some View {
        if layout == .fullLyrics {
            FullLyricsPlayer(model: model, preferences: preferences, close: close, findLyrics: findLyrics)
        } else if layout == .lyrics {
            LyricsOverlay(model: model, preferences: preferences)
        } else if model.playback == nil {
            PlayerEmptyState(model: model)
        } else {
            switch layout {
            case .artwork: ArtworkPlayer(model: model, settings: options, expand: { select(.combined) })
            case .album: AlbumPlayer(model: model, settings: options, fullLyrics: fullLyrics)
            case .compact: CompactPlayer(model: model, settings: options)
            case .lyrics: LyricsOverlay(model: model, preferences: preferences)
            case .combined: CombinedPlayer(model: model, preferences: preferences)
            case .fullLyrics: EmptyView()
            }
        }
    }
}

private struct PlayerWindowDrag: ViewModifier {
    let enabled: Bool
    let move: (Bool) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in move(false) }
                .onEnded { _ in
                    move(false)
                    move(true)
                })
        } else {
            // A .none gesture mask also disables the Full Lyrics buttons and scrolling.
            content
        }
    }
}

private struct ResizeGrip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
