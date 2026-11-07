import Foundation
import XCTest
@testable import Kanta

final class LyricsLibraryTests: XCTestCase {
    func testCacheOverrideRemovalAndOfflinePlayback() async throws {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        StubLyricsProtocol.setHandler { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(query.first { $0.name == "duration" }?.value, "190")
            XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Kanta/") == true)
            return (200, Data("""
                {"id":2,"trackName":"Lumière","artistName":"Isla June","albumName":"Low Tide",
                 "duration":190,"instrumental":false,"syncedLyrics":"[00:05.00]Remote"}
                """.utf8))
        }
        let track = makeTrack()
        let result = await fixture.library.load(track)
        XCTAssertEqual(result.lyrics?.lines.first?.text, "Remote")

        StubLyricsProtocol.setHandler { _ in throw URLError(.notConnectedToInternet) }
        let cached = await fixture.library.load(track)
        XCTAssertEqual(cached, result)
        let refreshed = await fixture.library.load(track, refresh: true)
        XCTAssertEqual(refreshed, .offline)

        _ = try await fixture.library.saveOverride("My local lyrics", for: track)
        let overridden = await fixture.library.load(track)
        XCTAssertEqual(overridden.lyrics?.lines.first?.text, "My local lyrics")
        let raw = await fixture.library.overrideText(for: track)
        XCTAssertEqual(raw, "My local lyrics")
        try await fixture.library.removeOverride(for: track)
        try await fixture.library.removeOverride(for: track)
        let restored = await fixture.library.load(track)
        XCTAssertEqual(restored, result)
    }

    func testMissingIsCachedAndOfflineIsRetriable() async throws {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let track = makeTrack()
        StubLyricsProtocol.setHandler { _ in throw URLError(.notConnectedToInternet) }
        let offline = await fixture.library.load(track)
        XCTAssertEqual(offline, .offline)
        StubLyricsProtocol.setHandler { request in
            request.url?.path == "/api/get" ? (404, Data()) : (200, Data("[]".utf8))
        }
        let missing = await fixture.library.load(track)
        XCTAssertEqual(missing, .missing)
        StubLyricsProtocol.setHandler { _ in
            XCTFail("A negative cache entry should prevent another request")
            throw URLError(.notConnectedToInternet)
        }
        let cached = await fixture.library.load(track)
        XCTAssertEqual(cached, .missing)
    }

    func testFileCacheRecoversFromMalformedEntry() async throws {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let track = makeTrack()
        let key = LyricsMatcher.cacheKey(for: track)
        try fixture.cache.write(Data("corrupt".utf8), folder: "Lyrics", key: key)
        StubLyricsProtocol.setHandler { request in
            request.url?.path == "/api/get" ? (404, Data()) : (200, Data("[]".utf8))
        }
        let status = await fixture.library.load(track)
        XCTAssertEqual(status, .missing)
        XCTAssertNotEqual(fixture.cache.read("Lyrics", key), Data("corrupt".utf8))
    }

    private struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache: LocalFiles
        let library: LyricsLibrary

        init() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubLyricsProtocol.self]
            let session = URLSession(configuration: configuration)
            cache = LocalFiles(directory: root.appendingPathComponent("cache"))
            library = LyricsLibrary(cache: cache, support: LocalFiles(directory: root.appendingPathComponent("support")),
                                    session: session)
        }

        func cleanup() { try? FileManager.default.removeItem(at: root) }
    }
}

private final class StubLyricsProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var handler: ((URLRequest) throws -> (Int, Data))?

    static func setHandler(_ handler: @escaping (URLRequest) throws -> (Int, Data)) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        do {
            guard let handler else { throw URLError(.unknown) }
            let (code, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
