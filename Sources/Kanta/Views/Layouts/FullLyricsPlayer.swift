import SwiftUI

struct FullLyricsPlayer: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var preferences: Preferences
    let close: () -> Void
    let findLyrics: () -> Void
    @ViewState private var follows = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(title: "Full Lyrics", icon: "text.alignleft")
                    .allowsHitTesting(false)
                if preferences.values.showPlainLyrics, let lyrics = model.lyrics.lyrics, !lyrics.synchronized,
                   !lyrics.instrumental, !lyrics.lines.isEmpty {
                    UnsyncedLyricsIndicator()
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Close Full Lyrics")
                    .accessibilityLabel("Close Full Lyrics")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background { WindowDragHandle().help("Drag to move Full Lyrics") }

            if let playback = model.playback {
                HStack(spacing: 13) {
                    SleeveArtwork(artwork: model.artwork, corner: 10)
                        .frame(width: 58, height: 58)
                    TrackDetails(track: playback.track, size: 19, showAlbum: true)
                    Spacer(minLength: 0)
                    Transport(model: model, size: 25)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                if preferences.values.showProgress {
                    ProgressStrip(playback: playback, seek: { model.send(.seek($0)) }, labels: true)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
                Divider()
                if let lyrics = model.lyrics.lyrics.flatMap({ preferences.values.lyricsForDisplay($0) }), !lyrics.instrumental, !lyrics.lines.isEmpty {
                    lyricList(lyrics, playback: playback)
                } else {
                    VStack(spacing: 11) {
                        Image(systemName: "text.quote").font(.title2).accessibilityHidden(true)
                        Text(preferences.values.lyricMessage(for: model.lyrics))
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        if model.lyrics != .loading {
                            Button("Find or Paste Lyrics…", action: findLyrics)
                                .controlSize(.small)
                        }
                    }
                    .padding(20)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                PlayerEmptyState(model: model)
            }
        }
        .onChange(of: model.track?.identity) { _ in follows = true }
    }

    private func lyricList(_ lyrics: Lyrics, playback: Playback) -> some View {
        let settings = preferences.values
        let offset = preferences.offset(for: playback.track)
        return LyricTimeline(playback: playback, lyrics: lyrics, offset: offset) { current in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: settings.lyricSpacing + 4) {
                        ForEach(lyrics.lines) { line in
                            let active = current == line.id
                            let label = Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: settings.lyricSize, weight: active ? .bold : .medium))
                                .foregroundStyle(active ? settings.highlight.color(dark: scheme == .dark) :
                                                    (lyrics.synchronized ? .secondary : .primary))
                                .multilineTextAlignment(settings.lyricAlignment.text)
                                .frame(maxWidth: .infinity, alignment: settings.lyricAlignment.frame)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background {
                                    if active {
                                        RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.065))
                                    }
                                }
                                .contentShape(Rectangle())
                            Group {
                                if settings.seekOnLyricClick, let time = lyrics.seekPosition(for: line, offset: offset) {
                                    Button { model.send(.seek(time)) } label: { label }
                                        .buttonStyle(.plain)
                                        .accessibilityAddTraits(active ? .isSelected : [])
                                        .help("Seek to this line")
                                } else {
                                    label.textSelection(.enabled)
                                        .accessibilityAddTraits(active ? .isSelected : [])
                                }
                            }
                            .id(line.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 45)
                }
                .background {
                    if lyrics.synchronized { ScrollIntent { follows = false } }
                }
                .id(playback.track.identity)
                .onAppear { if follows { scroll(proxy, to: current, animated: false) } }
                .onChange(of: current) { line in
                    if follows { scroll(proxy, to: line, animated: settings.animate && !reduceMotion) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if lyrics.synchronized && !follows {
                        Button {
                            follows = true
                            scroll(proxy, to: current, animated: settings.animate && !reduceMotion)
                        } label: {
                            Label("Current line", systemImage: "scope")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: Capsule())
                                .overlay { Capsule().strokeBorder(.primary.opacity(0.12)) }
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to line: Int?, animated: Bool) {
        withAnimation(animated ? .easeInOut(duration: 0.25) : nil) {
            proxy.scrollTo(line ?? 0, anchor: .center)
        }
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct ScrollIntent: NSViewRepresentable {
    let didScroll: () -> Void

    func makeNSView(context: Context) -> Observer { Observer() }
    func updateNSView(_ view: Observer, context: Context) { view.didScroll = didScroll }

    final class Observer: NSView {
        var didScroll: (() -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .keyDown]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                let inside = self.bounds.contains(point)
                if event.type == .scrollWheel && inside && event.scrollingDeltaY != 0 {
                    self.didScroll?()
                } else if event.type == .leftMouseDown && inside && self.bounds.maxX - point.x < 14 {
                    // The scrollbar lives at the trailing edge, including with overlay scrollbars.
                    self.didScroll?()
                } else if event.type == .keyDown && [116, 121, 125, 126].contains(event.keyCode) {
                    self.didScroll?()
                }
                return event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
