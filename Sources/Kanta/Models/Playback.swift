import Foundation

enum MusicSource: String, CaseIterable, Codable, Identifiable {
    case spotify, music

    var id: Self { self }
    var title: String { self == .spotify ? "Spotify" : "Apple Music" }
    var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
}

enum SourcePreference: String, CaseIterable, Identifiable {
    case automatic, spotify, music

    var id: Self { self }
    var source: MusicSource? { MusicSource(rawValue: rawValue) }
    var title: String { source?.title ?? "Automatic" }
}

struct Track: Equatable, Sendable {
    let source: MusicSource
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    var artworkURL: URL?

    var identity: String { "\(source.rawValue):\(id)" }
}

enum PlaybackState: Equatable {
    case playing, paused, stopped
}

struct Playback: Equatable {
    let track: Track
    var state: PlaybackState
    var anchor: TimeInterval
    var sampledAt: TimeInterval

    func position(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> TimeInterval {
        let elapsed = state == .playing ? max(0, uptime - sampledAt) : 0
        let position = max(0, anchor + elapsed)
        return track.duration > 0 ? min(track.duration, position) : position
    }
}

enum PlayerAvailability: Equatable {
    case ready
    case notInstalled
    case notRunning
    case noTrack
    case permissionDenied(MusicSource)
    case unavailable(MusicSource)

    var title: String {
        switch self {
        case .ready: return "Ready to listen"
        case .notInstalled: return "A music app is needed"
        case .notRunning: return "Ready when you are"
        case .noTrack: return "Nothing playing"
        case .permissionDenied: return "Allow music control"
        case .unavailable: return "Can’t reach the player"
        }
    }

    var detail: String {
        switch self {
        case .ready, .noTrack: return "Play a song to bring Kanta to life."
        case .notInstalled: return "Kanta works with Spotify and Apple Music."
        case .notRunning: return "Open Spotify or Music, then play a song."
        case .permissionDenied(let source): return "Allow Kanta to control \(source.title) in System Settings."
        case .unavailable(let source): return "\(source.title) isn’t responding. Kanta will try again."
        }
    }
}

enum PlayerCommand {
    case toggle, previous, next, seek(TimeInterval)
}

enum PlayerFailure: Error {
    case notRunning, noTrack, permissionDenied, unavailable
}

protocol MusicProvider {
    var source: MusicSource { get }
    func read() async throws -> Playback
    func send(_ command: PlayerCommand) async throws
    func artwork(for track: Track) async throws -> Data?
}

enum SourceSelection {
    static func choose(
        _ snapshots: [Playback], preference: SourcePreference, previous: MusicSource?
    ) -> Playback? {
        if let source = preference.source {
            return snapshots.first { $0.track.source == source }
        }
        let playing = snapshots.filter { $0.state == .playing }
        let candidates = playing.isEmpty ? snapshots.filter { $0.state == .paused } : playing
        let eligible = candidates.isEmpty ? snapshots : candidates
        return eligible.first { $0.track.source == previous } ?? eligible.first
    }
}
