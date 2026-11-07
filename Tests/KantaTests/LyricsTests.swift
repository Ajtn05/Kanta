import Foundation
import XCTest
@testable import Kanta

final class LyricsTests: XCTestCase {
    func testLRCMetadataMultipleTimestampsOffsetsAndInstrumentalBreak() {
        let lyrics = LRCParser.parse("""
        \u{FEFF}[ar:Isla June]
        [00:09.50][00:02.4]The tide is turning
        [00:05.012]
        [offset:+150]
        [99:85.10]Invalid
        [00:09.50]<00:09.50>Still turning
        """)
        XCTAssertEqual(lyrics.lines.compactMap(\.time).count, 3)
        XCTAssertEqual(lyrics.lines[0].time ?? -1, 2.25, accuracy: 0.0001)
        XCTAssertEqual(lyrics.lines[1].time ?? -1, 4.862, accuracy: 0.0001)
        XCTAssertEqual(lyrics.lines[1].text, "")
        XCTAssertEqual(lyrics.lines[2].text, "The tide is turning\nStill turning")
        XCTAssertEqual(lyrics.lines.map(\.id), [0, 1, 2])
    }

    func testPlainAndMalformedLyricsRemainReadable() {
        let lyrics = LRCParser.parse("[ti:Song]\r\nFirst line\r\n[xx:??]Second line")
        XCTAssertFalse(lyrics.synchronized)
        XCTAssertEqual(lyrics.lines.map(\.text), ["First line", "[xx:??]Second line"])
        XCTAssertNil(lyrics.activeIndex(at: 20, offset: 0))
        XCTAssertTrue(LRCParser.parse("[offset:50]").lines.isEmpty)
    }

    func testOffsetAndSeekAreInverse() {
        let lyrics = LRCParser.parse("[00:05.00]First\n[00:07.00]Second")
        XCTAssertNil(lyrics.activeIndex(at: 4.70, offset: 0.25))
        XCTAssertEqual(lyrics.activeIndex(at: 4.75, offset: 0.25), 0)
        XCTAssertEqual(lyrics.activeIndex(at: 7.10, offset: -0.25), 0)
        XCTAssertEqual(lyrics.seekPosition(for: lyrics.lines[1], offset: -0.25), 7.25)
        XCTAssertEqual(lyrics.seekPosition(for: lyrics.lines[0], offset: 10), 0)
    }

    func testMatchingRejectsOtherRecordingsAndPrefersMatchingAlbum() {
        let track = makeTrack()
        let records = [
            record(title: "Lumière (Live)", time: 191, text: "Live"),
            record(artist: "Someone else", time: 190, text: "Cover"),
            record(time: 210, text: "Long edit"),
            record(album: "Anthology", time: 190, text: "Compilation"),
            record(time: 191, text: "Original")
        ]
        XCTAssertEqual(LyricsMatcher.best(records, for: track)?.lines.first?.text, "Original")
        XCTAssertNil(LyricsMatcher.best(Array(records.prefix(3)), for: track))
    }

    func testMatchingUnderstandsInstrumentalsAndPlainFallback() {
        let empty = LyricsRecord(id: 1, trackName: "Lumière", artistName: "Isla June", albumName: "Low Tide",
                                 duration: 190, instrumental: true, plainLyrics: nil, syncedLyrics: nil)
        XCTAssertEqual(LyricsMatcher.best([empty], for: makeTrack())?.instrumental, true)
        let malformed = LyricsRecord(id: 2, trackName: "Lumière", artistName: "Isla June", albumName: "Low Tide",
                                     duration: 190, instrumental: false, plainLyrics: "Plain", syncedLyrics: "[00:03]")
        XCTAssertEqual(malformed.lyrics?.lines.first?.text, "Plain")
        XCTAssertEqual(malformed.lyrics?.synchronized, false)
    }

    private func record(title: String = "Lumiere", artist: String = "Isla June", album: String = "Low Tide",
                        time: Double, text: String) -> LyricsRecord {
        LyricsRecord(id: 1, trackName: title, artistName: artist, albumName: album, duration: time,
                     instrumental: false, plainLyrics: nil, syncedLyrics: "[00:00.0]" + text)
    }
}

func makeTrack(_ source: MusicSource = .spotify, id: String = "001", duration: Double = 190) -> Track {
    Track(source: source, id: id, title: "Lumière", artist: "Isla June", album: "Low Tide", duration: duration)
}
