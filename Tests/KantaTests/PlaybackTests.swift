import Foundation
import Combine
import XCTest
@testable import Kanta

final class PlaybackTests: XCTestCase {
    func testInterpolationAndBounds() {
        var playback = Playback(track: makeTrack(), state: .playing, anchor: 186, sampledAt: 50)
        XCTAssertEqual(playback.position(at: 49), 186)
        XCTAssertEqual(playback.position(at: 52.5), 188.5)
        XCTAssertEqual(playback.position(at: 70), 190)
        playback.state = .paused
        XCTAssertEqual(playback.position(at: 70), 186)
        playback.state = .stopped
        XCTAssertEqual(playback.position(at: 70), 186)
    }

    func testAutomaticSelectionIsStableAndManualSelectionIsStrict() {
        let spotify = Playback(track: makeTrack(), state: .playing, anchor: 0, sampledAt: 0)
        var music = Playback(track: makeTrack(.music), state: .paused, anchor: 0, sampledAt: 0)
        XCTAssertEqual(SourceSelection.choose([spotify, music], preference: .automatic, previous: .music), spotify)
        XCTAssertEqual(SourceSelection.choose([spotify, music], preference: .music, previous: .spotify), music)
        XCTAssertNil(SourceSelection.choose([spotify], preference: .music, previous: .music))
        music.state = .playing
        XCTAssertEqual(SourceSelection.choose([spotify, music], preference: .automatic, previous: .music), music)
    }

    func testProviderSnapshotUnitsAndMissingData() throws {
        let runner = AppleScriptRunner()
        let fields = ["ABC", "A Song", "An Artist", "An Album", "193400", "36,25", "playing", ""]
        let spotify = try SpotifyProvider(runner: runner).decodeSnapshot(fields.joined(separator: "\u{1F}"), uptime: 25)
        XCTAssertEqual(spotify.track.duration, 193.4, accuracy: 0.0001)
        XCTAssertEqual(spotify.anchor, 36.25)
        XCTAssertEqual(spotify.position(at: 26), 37.25)
        var musicFields = fields
        musicFields[4] = "193.4"
        musicFields[6] = "paused"
        let music = try AppleMusicProvider(runner: runner).decodeSnapshot(musicFields.joined(separator: "\u{1F}"), uptime: 25)
        XCTAssertEqual(music.track.duration, 193.4)
        XCTAssertEqual(music.position(at: 26), 36.25)
        XCTAssertThrowsError(try AppleMusicProvider(runner: runner).decodeSnapshot(""))
    }

    func testAppleMusicRawArtworkDecoding() {
        XCTAssertEqual(AppleMusicProvider.decodeArtwork("«data PNGfCAFEBEEF»"), Data([0xca, 0xfe, 0xbe, 0xef]))
        XCTAssertNil(AppleMusicProvider.decodeArtwork("«data PNGfCAFEZB»"))
        XCTAssertNil(AppleMusicProvider.decodeArtwork("«data PNGfABC»"))
    }

    func testAppleScriptsCompileWithoutLaunchingProviders() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let runner = AppleScriptRunner()
        let music = AppleMusicProvider(runner: runner)
        let spotify = SpotifyProvider(runner: runner)
        for provider in [music as any ScriptProvider, spotify as any ScriptProvider] {
            var bodies = [provider.snapshotScript]
            bodies += [PlayerCommand.toggle, .previous, .next, .seek(45.25)].compactMap(provider.commandScript)
            if provider.source == .music { bodies.append(music.artworkScript("0123456789ABCDEF")) }
            for body in bodies {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osacompile")
                let path = temporary.appendingPathComponent(UUID().uuidString + ".scpt").path
                process.arguments = ["-o", path, "-e", AppleScriptRunner.wrapped(body, in: provider.source)]
                let output = Pipe()
                process.standardError = output
                try process.run()
                let errors = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                XCTAssertEqual(process.terminationStatus, 0, String(decoding: errors, as: UTF8.self))
            }
        }
    }

    @MainActor
    func testModelTrackChangesPauseAndSeekWithMockProvider() async throws {
        let mock = DemoProvider()
        let model = PlayerModel(providers: [mock], useSystemAvailability: false, demoLyrics: DemoProvider.lyrics)
        model.start(source: .automatic)
        defer { model.stop() }

        try await until { model.track?.id == "kanta-demo-0" && model.isPlaying }
        XCTAssertTrue(model.lyrics.lyrics?.synchronized == true)
        model.send(.toggle)
        try await until { model.playback?.state == .paused }
        try await untilAsync { (try? await mock.read().state) == .paused }
        try await until { model.playback?.state == .paused }
        try await Task.sleep(for: .milliseconds(50))
        model.send(.seek(72))
        try await until { abs(model.position - 72) < 0.01 }
        try await untilAsync { (try? await mock.read().anchor) == 72 }
        try await Task.sleep(for: .milliseconds(50))
        model.send(.next)
        try await until { model.track?.id == "kanta-demo-1" }
        model.changeSource(to: .music)
        try await until { model.availability == .notInstalled && model.track == nil }
    }

    @MainActor
    func testTemporaryProviderFailureKeepsTrackAndLyricsVisible() async throws {
        let provider = IntermittentProvider()
        let model = PlayerModel(providers: [provider], useSystemAvailability: false, demoLyrics: DemoProvider.lyrics)
        model.start(source: .automatic)
        defer { model.stop() }
        try await until { model.track != nil }

        var droppedTrack = false
        let observer = model.$playback.dropFirst().sink { if $0 == nil { droppedTrack = true } }
        defer { observer.cancel() }
        await provider.failNextRead()
        model.refresh()
        try await untilAsync { await provider.readCount >= 3 }
        XCTAssertFalse(droppedTrack)
        XCTAssertNotNil(model.lyrics.lyrics)

        await provider.setUnavailable()
        model.refresh()
        try await until { model.track == nil }
        XCTAssertTrue(droppedTrack)
    }

    @MainActor
    private func until(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for the playback model")
    }

    @MainActor
    private func untilAsync(_ predicate: () async -> Bool) async throws {
        for _ in 0..<100 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for the playback provider")
    }
}

private actor IntermittentProvider: MusicProvider {
    nonisolated let source = MusicSource.spotify
    private(set) var readCount = 0
    private var failOnce = false
    private var unavailable = false

    func failNextRead() { failOnce = true }
    func setUnavailable() { unavailable = true }

    func read() async throws -> Playback {
        readCount += 1
        if failOnce || unavailable {
            failOnce = false
            throw PlayerFailure.notRunning
        }
        return Playback(track: makeTrack(), state: .playing, anchor: 12,
                        sampledAt: ProcessInfo.processInfo.systemUptime)
    }

    func send(_ command: PlayerCommand) async throws {}
    func artwork(for track: Track) async throws -> Data? { nil }
}
