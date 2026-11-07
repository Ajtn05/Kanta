import AppKit
import Combine

enum PlayerLayout: String, Codable, CaseIterable, Identifiable {
    case artwork, compact, lyrics, combined, fullLyrics
    var id: Self { self }

    static var miniPlayers: [Self] { [.artwork, .compact, .lyrics, .combined] }

    var title: String {
        switch self {
        case .artwork: return "Artwork MiniPlayer"
        case .compact: return "Compact MiniPlayer"
        case .lyrics: return "Lyrics Only"
        case .combined: return "Combined MiniPlayer"
        case .fullLyrics: return "Full Lyrics"
        }
    }

    var icon: String {
        switch self {
        case .artwork: return "square"
        case .compact: return "rectangle"
        case .lyrics: return "captions.bubble"
        case .combined: return "rectangle.split.2x1"
        case .fullLyrics: return "text.alignleft"
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .artwork: return CGSize(width: 240, height: 240)
        case .compact: return CGSize(width: 360, height: 96)
        case .lyrics: return CGSize(width: 280, height: 88)
        case .combined: return CGSize(width: 380, height: 280)
        case .fullLyrics: return CGSize(width: 400, height: 380)
        }
    }

    var suggestedSize: CGSize {
        switch self {
        case .artwork: return CGSize(width: 288, height: 288)
        case .compact: return CGSize(width: 410, height: 96)
        case .lyrics: return CGSize(width: 400, height: 140)
        case .combined: return CGSize(width: 540, height: 300)
        case .fullLyrics: return CGSize(width: 478, height: 590)
        }
    }

    func minimumSize(arrangement: CombinedArrangement) -> CGSize {
        if self == .combined && arrangement == .horizontal {
            return CGSize(width: 520, height: minimumSize.height)
        }
        return minimumSize
    }
}

enum Theme: String, Codable, CaseIterable {
    case system = "System", light = "Light", dark = "Dark"

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum PlayerBackground: String, Codable, CaseIterable {
    case material = "Frosted", solid = "Solid", glass = "Liquid Glass"

    static var supportsGlass: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }
}

enum CombinedArrangement: String, Codable, CaseIterable {
    case automatic = "Automatic", horizontal = "Horizontal", vertical = "Vertical"
}

enum CombinedLyricsLayout: String, Codable, CaseIterable {
    case compact = "Compact", fill = "Fill available space"
}

enum LyricAlignment: String, Codable, CaseIterable {
    case leading = "Left", center = "Center", trailing = "Right"
}

enum Highlight: String, Codable, CaseIterable {
    case primary = "Adaptive", mint = "Mint", peach = "Peach", lilac = "Lilac"
}

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String
}

enum ShortcutAction: String, CaseIterable {
    case toggle = "Show or Hide MiniPlayer"
    case cycle = "Switch to Next Layout"
    case full = "Show Full Lyrics"
}

struct SettingsValues: Codable, Equatable {
    var source: SourcePreference = .automatic
    var layout: PlayerLayout = .artwork
    var theme: Theme = .system
    var showDock = false
    var hasOnboarded = false
    var adaptive = true
    var backgroundOpacity = 1.0
    var cornerRadius = 22.0
    var animate = true
    var showControls = false
    var showMetadata = true
    var showProgress = true
    var onTop = true
    var rememberFrames = true
    var playerScale = 1.0
    var arrangement: CombinedArrangement = .automatic
    var lyricSize = 21.0
    var lyricSpacing = 5.0
    var lyricAlignment: LyricAlignment = .center
    var lyricLines = 3
    var highlight: Highlight = .primary
    var lyricOpacity = 0.94
    var clickThrough = false
    var lyricControls = true
    var menuLyrics = false
    var globalOffset = 0.0
    var shortcuts: [String: Shortcut] = [:]

    // Optional storage lets existing preference files adopt new defaults without a reset.
    private var storedBackground: PlayerBackground?
    private var storedSeekOnLyricClick: Bool?
    private var storedCombinedLyricsLayout: CombinedLyricsLayout?

    var combinedLyricsLayout: CombinedLyricsLayout {
        get { storedCombinedLyricsLayout ?? .compact }
        set { storedCombinedLyricsLayout = newValue }
    }

    var background: PlayerBackground {
        get { storedBackground ?? .material }
        set { storedBackground = newValue }
    }

    var seekOnLyricClick: Bool {
        get { storedSeekOnLyricClick ?? true }
        set { storedSeekOnLyricClick = newValue }
    }
}

extension SourcePreference: Codable {}

@MainActor
final class Preferences: ObservableObject {
    @Published var values: SettingsValues {
        didSet {
            if let data = try? JSONEncoder().encode(values) {
                defaults?.set(data, forKey: "preferences.v1")
            }
        }
    }

    @Published private(set) var offsets: [String: Double]
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        let data = defaults?.data(forKey: "preferences.v1")
        self.values = data.flatMap { try? JSONDecoder().decode(SettingsValues.self, from: $0) } ?? SettingsValues()
        self.offsets = defaults?.dictionary(forKey: "lyricOffsets")?.compactMapValues { $0 as? Double } ?? [:]
    }

    func offset(for track: Track?) -> TimeInterval {
        values.globalOffset + (track.flatMap { offsets[$0.identity] } ?? 0)
    }

    func adjustOffset(for track: Track, by amount: Double?) {
        if let amount {
            let updated = (offsets[track.identity, default: 0] + amount) * 100
            offsets[track.identity] = updated.rounded() / 100
        } else {
            offsets.removeValue(forKey: track.identity)
        }
        defaults?.set(offsets, forKey: "lyricOffsets")
    }

    func frame(for layout: PlayerLayout) -> CGRect? {
        guard values.rememberFrames, let saved = defaults?.string(forKey: "frame." + layout.rawValue) else { return nil }
        let frame = NSRectFromString(saved)
        return frame.width > 0 && frame.height > 0 ? frame : nil
    }

    func saveFrame(_ frame: CGRect, for layout: PlayerLayout) {
        guard values.rememberFrames else { return }
        defaults?.set(NSStringFromRect(frame), forKey: "frame." + layout.rawValue)
    }

    func select(_ layout: PlayerLayout) {
        guard PlayerLayout.miniPlayers.contains(layout) else { return }
        values.layout = layout
    }

    func cycleLayout() {
        let layouts = PlayerLayout.miniPlayers
        let index = layouts.firstIndex(of: values.layout) ?? 0
        select(layouts[(index + 1) % layouts.count])
    }
}
