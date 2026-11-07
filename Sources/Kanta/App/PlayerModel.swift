import AppKit
import Combine

@MainActor
final class PlayerModel: ObservableObject {
    @Published private(set) var playback: Playback?
    @Published private(set) var availability: PlayerAvailability = .notRunning
    @Published private(set) var lyrics: LyricsStatus = .idle
    @Published private(set) var artwork: Artwork?
    @Published private(set) var commandError: String?

    private let providers: [any MusicProvider]
    private let lyricsLibrary: LyricsLibrary
    private let artworkLibrary: ArtworkLibrary
    private let useSystemAvailability: Bool
    private let demoLyrics: Lyrics?
    private var preference: SourcePreference = .automatic
    private var loop: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var lastArtworkAttempt = Date.distantPast
    private var running = false
    private var missedCurrentSource = false

    var track: Track? { playback?.track }
    var isPlaying: Bool { playback?.state == .playing }
    var position: TimeInterval { playback?.position() ?? 0 }

    init(
        providers: [any MusicProvider], lyrics: LyricsLibrary = LyricsLibrary(),
        artwork: ArtworkLibrary = ArtworkLibrary(), useSystemAvailability: Bool = true, demoLyrics: Lyrics? = nil
    ) {
        self.providers = providers
        self.lyricsLibrary = lyrics
        self.artworkLibrary = artwork
        self.useSystemAvailability = useSystemAvailability
        self.demoLyrics = demoLyrics
    }

    func start(source: SourcePreference) {
        preference = source
        running = true
        refresh()
    }

    func changeSource(to source: SourcePreference) {
        guard source != preference else { return }
        preference = source
        missedCurrentSource = false
        refresh()
    }

    func refresh() {
        guard running else { return }
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.poll()
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    func stop() {
        running = false
        loop?.cancel()
        lyricsTask?.cancel()
        artworkTask?.cancel()
        commandTask?.cancel()
    }

    private func poll() async -> Double {
        let sources = providers.filter { preference.source == nil || $0.source == preference.source }
        let active = sources.filter {
            !useSystemAvailability || !NSRunningApplication.runningApplications(withBundleIdentifier: $0.source.bundleID).isEmpty
        }

        var snapshots: [Playback] = []
        var problem: PlayerAvailability = .noTrack
        for provider in active {
            guard !Task.isCancelled else { return 6 }
            do {
                snapshots.append(try await provider.read())
            } catch PlayerFailure.permissionDenied {
                problem = .permissionDenied(provider.source)
            } catch PlayerFailure.noTrack {
                continue
            } catch PlayerFailure.notRunning {
                continue
            } catch {
                if case .noTrack = problem { problem = .unavailable(provider.source) }
            }
        }

        guard !Task.isCancelled else { return 6 }
        if commandTask != nil { return 1 }
        let next = SourceSelection.choose(snapshots, preference: preference, previous: track?.source)
        // A single transient discovery or Apple Event failure must not tear down the lyric view.
        let currentSourceMissing = track.map { current in
            (preference.source == nil || preference.source == current.source)
                && !snapshots.contains { $0.track.source == current.source }
                && next?.state != .playing
        } ?? false
        if currentSourceMissing && !missedCurrentSource {
            missedCurrentSource = true
            return 0.65
        }
        missedCurrentSource = currentSourceMissing
        let installed = sources.filter {
            !useSystemAvailability || NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.source.bundleID) != nil
        }
        let status: PlayerAvailability
        if next != nil {
            status = .ready
        } else if installed.isEmpty {
            status = .notInstalled
        } else if active.isEmpty {
            status = .notRunning
        } else {
            status = problem
        }
        accept(next, availability: status)
        if next?.state == .playing { return 1.6 }
        return next == nil ? 6 : 3
    }

    private func accept(_ newPlayback: Playback?, availability status: PlayerAvailability) {
        let previous = track
        if availability != status { availability = status }
        // Keep the existing clock while both samples agree, especially when paused.
        let samplesAgree: Bool
        if let current = playback, let incoming = newPlayback {
            samplesAgree = current.track == incoming.track && current.state == incoming.state
                && abs(current.position(at: incoming.sampledAt) - incoming.anchor) < 0.12
        } else {
            samplesAgree = playback == newPlayback
        }
        if !samplesAgree { playback = newPlayback }
        let trackChanged = track?.identity != previous?.identity
        if trackChanged || track?.artworkURL != previous?.artworkURL {
            artwork = nil
            artworkTask?.cancel()
            artworkTask = nil
            lastArtworkAttempt = .distantPast
        }
        if trackChanged || track?.title != previous?.title || track?.artist != previous?.artist ||
            track?.album != previous?.album {
            commandError = nil
            loadLyrics()
        }
        loadArtworkIfNeeded()
    }

    private func loadArtworkIfNeeded() {
        guard artwork == nil, artworkTask == nil, Date().timeIntervalSince(lastArtworkAttempt) > 60,
              let track, let provider = providers.first(where: { $0.source == track.source }) else { return }
        lastArtworkAttempt = Date()
        artworkTask = Task {
            let result = await artworkLibrary.load(track, provider: provider)
            guard !Task.isCancelled else { return }
            artwork = result
            artworkTask = nil
        }
    }

    func loadLyrics(refresh: Bool = false) {
        lyricsTask?.cancel()
        guard let track else {
            lyrics = .idle
            return
        }
        if let demoLyrics {
            lyrics = .available(demoLyrics)
            return
        }
        lyrics = .loading
        lyricsTask = Task {
            let result = await lyricsLibrary.load(track, refresh: refresh)
            if !Task.isCancelled { lyrics = result }
        }
    }

    func overrideText(for track: Track) async -> String? {
        await lyricsLibrary.overrideText(for: track)
    }

    func saveLyrics(_ text: String, for edited: Track) async throws {
        let result = try await lyricsLibrary.saveOverride(text, for: edited)
        if track?.identity == edited.identity {
            lyricsTask?.cancel()
            lyrics = .available(result)
        }
    }

    func removeLyrics(for edited: Track) async throws {
        try await lyricsLibrary.removeOverride(for: edited)
        if track?.identity == edited.identity { loadLyrics() }
    }

    func send(_ command: PlayerCommand) {
        guard commandTask == nil, let playback,
              let provider = providers.first(where: { $0.source == playback.track.source }) else { return }
        commandError = nil
        var optimistic = playback
        var outgoing = command
        switch command {
        case .seek(let seconds):
            let duration = playback.track.duration
            let limit = duration > 0 ? duration : seconds
            let target = max(0, min(seconds, limit))
            outgoing = .seek(target)
            optimistic.anchor = target
        case .toggle:
            optimistic.anchor = position
            optimistic.state = isPlaying ? .paused : .playing
        case .next, .previous:
            break
        }
        optimistic.sampledAt = ProcessInfo.processInfo.systemUptime
        switch command {
        case .next, .previous: break
        case .toggle, .seek: self.playback = optimistic
        }

        commandTask = Task {
            do {
                try await provider.send(outgoing)
            } catch PlayerFailure.permissionDenied {
                self.playback = playback
                commandError = "Check Automation access for \(provider.source.title)."
            } catch {
                self.playback = playback
                commandError = "Playback command didn’t reach \(provider.source.title)."
            }
            commandTask = nil
            refresh()
        }
    }
}
