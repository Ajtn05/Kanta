import Foundation

actor LyricsLibrary {
    private struct Entry: Codable {
        let date: Date
        let lyrics: Lyrics?
    }

    private let cache: LocalFiles
    private let support: LocalFiles
    private let session: URLSession
    private let userAgent: String
    private var nextRequest = Date.distantPast
    private var inFlight: (id: UUID, task: Task<LyricsStatus, Never>)?

    init(cache: LocalFiles = .cache, support: LocalFiles = .support, session: URLSession = .shared) {
        self.cache = cache
        self.support = support
        self.session = session
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let project = Bundle.main.object(forInfoDictionaryKey: "KantaProjectURL") as? String ?? "https://example.com/Kanta"
        self.userAgent = "Kanta/\(version) (\(project))"
    }

    func load(_ track: Track, refresh: Bool = false) async -> LyricsStatus {
        if let data = support.read("Overrides", track.identity), let text = String(data: data, encoding: .utf8) {
            let lyrics = LRCParser.parse(text)
            if !lyrics.lines.isEmpty { return .available(lyrics) }
        }
        let key = LyricsMatcher.cacheKey(for: track)
        if !refresh, let data = cache.read("Lyrics", key),
           let entry = try? JSONDecoder().decode(Entry.self, from: data) {
            if let lyrics = entry.lyrics { return .available(lyrics) }
            if Date().timeIntervalSince(entry.date) < 86_400 { return .missing }
        }

        guard !track.title.isEmpty, !track.artist.isEmpty else { return .missing }
        // Serialize lookups across track changes. An old request may finish and warm the cache.
        while let current = inFlight {
            _ = await current.task.value
            if Task.isCancelled { return .idle }
            if inFlight?.id == current.id { inFlight = nil }
            if !refresh, let data = cache.read("Lyrics", key),
               let entry = try? JSONDecoder().decode(Entry.self, from: data),
               Date().timeIntervalSince(entry.date) < 86_400 {
                return entry.lyrics.map(LyricsStatus.available) ?? .missing
            }
        }
        guard !Task.isCancelled else { return .idle }
        let id = UUID()
        let request = Task { await fetchAndCache(track, key: key) }
        inFlight = (id, request)
        let result = await request.value
        if inFlight?.id == id { inFlight = nil }
        return result
    }

    func saveOverride(_ text: String, for track: Track) throws -> Lyrics {
        let lyrics = LRCParser.parse(text)
        guard lyrics.lines.contains(where: { !$0.text.isEmpty }) else { throw OverrideError.empty }
        try support.write(Data(text.utf8), folder: "Overrides", key: track.identity)
        return lyrics
    }

    func removeOverride(for track: Track) throws {
        try support.remove("Overrides", track.identity)
    }

    func overrideText(for track: Track) -> String? {
        support.read("Overrides", track.identity).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func fetchAndCache(_ track: Track, key: String) async -> LyricsStatus {
        do {
            let signature = [URLQueryItem(name: "track_name", value: track.title),
                             URLQueryItem(name: "artist_name", value: track.artist)]
            var exact = signature
            if !track.album.isEmpty { exact.append(URLQueryItem(name: "album_name", value: track.album)) }
            if (1...3600).contains(track.duration) {
                exact.append(URLQueryItem(name: "duration", value: String(Int(track.duration.rounded()))))
            }
            let record: LyricsRecord? = try await request("get", query: exact)
            var lyrics = record.flatMap { LyricsMatcher.best([$0], for: track) }
            if lyrics == nil {
                let candidates: [LyricsRecord] = try await request("search", query: signature) ?? []
                lyrics = LyricsMatcher.best(candidates, for: track)
            }

            let entry = Entry(date: Date(), lyrics: lyrics)
            if let data = try? JSONEncoder().encode(entry) {
                try? cache.write(data, folder: "Lyrics", key: key)
                cache.prune("Lyrics", maximumBytes: 12_000_000)
            }
            return lyrics.map(LyricsStatus.available) ?? .missing
        } catch let error as URLError {
            let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                                               .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed]
            return offline.contains(error.code) ? .offline : .failed
        } catch {
            return .failed
        }
    }

    private func request<Value: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> Value? {
        let wait = nextRequest.timeIntervalSinceNow
        if wait > 2 { throw URLError(.resourceUnavailable) }
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = "/api/" + path
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        nextRequest = Date().addingTimeInterval(0.3)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if response.statusCode == 404 { return nil }
        if response.statusCode == 429 {
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            let seconds = retryAfter.flatMap(Double.init)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            let date = retryAfter.flatMap { formatter.date(from: $0) }
            nextRequest = max(nextRequest, date ?? Date().addingTimeInterval(seconds ?? 60))
        }
        guard response.statusCode == 200, data.count <= 2_000_000 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    enum OverrideError: LocalizedError {
        case empty
        var errorDescription: String? { "Enter at least one line of lyrics." }
    }
}
