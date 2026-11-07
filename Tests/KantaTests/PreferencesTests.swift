import AppKit
import XCTest
@testable import Kanta

final class PreferencesTests: XCTestCase {
    func testNewAppearanceAndLyricPreferencesPreserveOlderSettings() throws {
        var settings = SettingsValues()
        settings.theme = .dark
        settings.layout = .lyrics
        settings.lyricSize = 28
        settings.background = .solid
        settings.seekOnLyricClick = false
        let encoded = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(SettingsValues.self, from: encoded)
        XCTAssertEqual(restored.background, .solid)
        XCTAssertFalse(restored.seekOnLyricClick)

        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "storedBackground")
        legacy.removeValue(forKey: "storedSeekOnLyricClick")
        let migrated = try JSONDecoder().decode(SettingsValues.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.theme, .dark)
        XCTAssertEqual(migrated.layout, .lyrics)
        XCTAssertEqual(migrated.lyricSize, 28)
        XCTAssertEqual(migrated.background, .material)
        XCTAssertTrue(migrated.seekOnLyricClick)
    }

    @MainActor
    func testPreferencesLayoutFramesAndTrackOffsetsPersist() async throws {
        let name = "Kanta.Tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        let track = makeTrack()
        let artwork = CGRect(x: 25, y: 40, width: 230, height: 230)
        let lyrics = CGRect(x: 70, y: 80, width: 420, height: 150)
        let original = Preferences(defaults: defaults)
        original.select(.combined)
        original.cycleLayout()
        XCTAssertEqual(original.values.layout, .artwork)
        original.select(.fullLyrics)
        XCTAssertEqual(original.values.layout, .artwork)
        original.select(.lyrics)
        original.values.source = .music
        original.values.globalOffset = 0.1
        original.adjustOffset(for: track, by: 0.25)
        original.adjustOffset(for: track, by: 0.1)
        original.saveFrame(artwork, for: .artwork)
        original.saveFrame(lyrics, for: .lyrics)

        let restored = Preferences(defaults: defaults)
        XCTAssertEqual(restored.values.layout, .lyrics)
        XCTAssertEqual(restored.values.source, .music)
        XCTAssertEqual(restored.offset(for: track), 0.45, accuracy: 0.0001)
        XCTAssertEqual(restored.frame(for: .artwork), artwork)
        XCTAssertEqual(restored.frame(for: .lyrics), lyrics)
        restored.adjustOffset(for: track, by: nil)
        XCTAssertEqual(restored.offset(for: track), 0.1)
        restored.values.rememberFrames = false
        XCTAssertNil(restored.frame(for: .artwork))
    }

    @MainActor
    func testWindowPlacementAcrossDisplaysAndDisconnect() async {
        let primary = CGRect(x: 0, y: 0, width: 1400, height: 900)
        let secondary = CGRect(x: -1200, y: 20, width: 1200, height: 760)
        let saved = CGRect(x: -800, y: 300, width: 300, height: 300)
        let minimum = PlayerLayout.artwork.minimumSize
        XCTAssertEqual(WindowPlacement.fitted(saved, to: [primary, secondary], minimum: minimum, square: true), saved)
        let fitted = WindowPlacement.fitted(saved, to: [primary], minimum: minimum, square: true)
        XCTAssertTrue(primary.contains(fitted))
        XCTAssertEqual(fitted.width, fitted.height)
    }

    @MainActor
    func testOldUndersizedFramesExpandToUsableMinimums() async {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let old = CGRect(x: 120, y: 220, width: 150, height: 44)
        for layout in PlayerLayout.allCases {
            let minimum = layout.minimumSize
            let fitted = WindowPlacement.fitted(old, to: [screen], minimum: minimum, square: layout == .artwork)
            XCTAssertGreaterThanOrEqual(fitted.width, minimum.width)
            XCTAssertGreaterThanOrEqual(fitted.height, minimum.height)
            XCTAssertTrue(screen.contains(fitted))
        }
        let horizontal = PlayerLayout.combined.minimumSize(arrangement: .horizontal)
        XCTAssertGreaterThan(horizontal.width, PlayerLayout.combined.minimumSize.width)
    }
}
