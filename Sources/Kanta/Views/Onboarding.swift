import SwiftUI

struct Onboarding: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var login: LoginItem
    let finish: () -> Void
    @ViewState private var step: SetupStep = .source
    @ViewState private var draft: SettingsValues
    @ViewState private var launchAtLogin: Bool

    init(preferences: Preferences, login: LoginItem, finish: @escaping () -> Void) {
        self.preferences = preferences
        self.login = login
        self.finish = finish
        _draft = ViewState(initialValue: preferences.values)
        _launchAtLogin = ViewState(initialValue: login.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 13) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Kanta").font(.system(size: 24, weight: .semibold))
                    Text("A few choices to make it yours.").foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                ForEach(SetupStep.allCases) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(item.index + 1)  \(item.label)")
                            .font(.system(size: 11, weight: item == step ? .semibold : .regular))
                            .foregroundStyle(item == step ? .primary : .secondary)
                        Capsule().fill(item.index <= step.index ? Color.accentColor : Color.primary.opacity(0.1))
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title).font(.system(size: 21, weight: .semibold))
                        Text(step.detail).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    stepContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.trailing, 4)
            }
            .id(step)
            Divider()
            HStack {
                if step != .source {
                    Button("Back") { step = SetupStep.allCases[step.index - 1] }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                }
                Spacer()
                Text("You can change these in Preferences.")
                    .font(.caption).foregroundStyle(.secondary)
                Button(step == .ready ? "Open My Player" : "Continue", action: advance)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 660, height: 610)
        .preferredColorScheme(draft.theme == .dark ? .dark : (draft.theme == .light ? .light : nil))
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .source: source
        case .player: player
        case .lyrics: lyrics
        case .appearance: appearance
        case .ready: ready
        }
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 24) {
            Picker("Playback source", selection: $draft.source) {
                ForEach(SourcePreference.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            tip("Play a song in your music app", "Automatic follows the app that is playing. You can also choose Spotify or Apple Music directly.", icon: "music.note")
            tip("Allow Automation when asked", "macOS will ask before Kanta reads or controls your music app. No permission is requested during setup.", icon: "lock.shield")
            tip("Find Kanta in the menu bar", "The lyrics menu opens your player, lyrics, and preferences.", icon: "text.quote")
        }
    }

    private var player: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PlayerLayout.miniPlayers) { layout in
                    Button { draft.layout = layout } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: layout.icon)
                                .font(.system(size: 20)).frame(width: 28, height: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(layout.title.replacingOccurrences(of: " MiniPlayer", with: ""))
                                    .font(.callout.weight(.semibold))
                                Text(layout.setupDescription).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if draft.layout == layout {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                        .background(draft.layout == layout ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.035),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(draft.layout == layout ? Color.accentColor : Color.primary.opacity(0.12)) }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.layout == layout ? .isSelected : [])
                }
            }
            Picker("Starting size", selection: $draft.playerScale) {
                Text("Small").tag(0.85)
                Text("Medium").tag(1.0)
                Text("Large").tag(1.20)
            }
            .pickerStyle(.segmented)
            Toggle("Show track information", isOn: $draft.showMetadata)
            Toggle("Show playback progress", isOn: $draft.showProgress)
        }
    }

    private var lyrics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Show plain lyrics when live lyrics are unavailable", isOn: $draft.showPlainLyrics)
            Text("Live lyrics are always preferred. Plain lyrics stay still and can be scrolled; a small clock shows they’re unsynced.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Combined lyric layout", selection: $draft.combinedLyricsLayout) {
                ForEach(CombinedLyricsLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if draft.combinedLyricsLayout == .compact {
                Stepper("Compact preview lines: \(draft.lyricLines)", value: $draft.lyricLines, in: 1...5)
            }
            HStack {
                Text("Font size")
                Slider(value: $draft.lyricSize, in: 13...36, step: 1)
                Text("\(Int(draft.lyricSize)) pt").monospacedDigit().frame(width: 42)
            }
            Picker("Alignment", selection: $draft.lyricAlignment) {
                ForEach(LyricAlignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Seek when clicking live lyrics", isOn: $draft.seekOnLyricClick)
            Toggle("Show live lyrics in the menu bar", isOn: $draft.menuLyrics)
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Appearance", selection: $draft.theme) {
                ForEach(Theme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Background", selection: $draft.background) {
                ForEach(PlayerBackground.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if draft.background == .glass && !PlayerBackground.supportsGlass {
                Text("Liquid Glass uses the frosted style on this Mac.").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Tint surfaces with album artwork", isOn: $draft.adaptive)
            HStack {
                Text("Background opacity")
                Slider(value: $draft.backgroundOpacity, in: 0.2...1, step: 0.05)
                Text(draft.backgroundOpacity, format: .percent).monospacedDigit().frame(width: 42)
            }
            HStack {
                Text("Corner radius")
                Slider(value: $draft.cornerRadius, in: 0...32, step: 1)
                Text("\(Int(draft.cornerRadius))").monospacedDigit().frame(width: 42)
            }
            Toggle("Animate transitions", isOn: $draft.animate)
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Label(draft.layout.title, systemImage: draft.layout.icon).font(.headline)
                Text("\(draft.source.title) · \(draft.theme.rawValue) appearance")
                    .font(.callout).foregroundStyle(.secondary)
                Text(draft.showPlainLyrics ? "Live lyrics, with plain lyrics as a fallback" : "Live lyrics only")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            Toggle("Keep the player above other windows", isOn: $draft.onTop)
            Toggle("Remember each layout’s size and position", isOn: $draft.rememberFrames)
            Toggle("Show Kanta in the Dock", isOn: $draft.showDock)
            Toggle("Launch at Login", isOn: $launchAtLogin)
            if let error = login.error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func advance() {
        if step != .ready {
            step = SetupStep.allCases[step.index + 1]
        } else {
            if launchAtLogin != login.enabled {
                login.setEnabled(launchAtLogin)
                if login.error != nil { return }
            }
            preferences.values = draft
            finish()
        }
    }

    private func tip(_ title: String, _ detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.system(size: 19)).foregroundStyle(.secondary).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum SetupStep: Int, CaseIterable, Identifiable {
    case source, player, lyrics, appearance, ready
    var id: Self { self }
    var index: Int { rawValue }
    var label: String { ["Source", "Player", "Lyrics", "Appearance", "Ready"][index] }
    var title: String { ["Start with your music", "Choose your player", "Make room for the words", "Set the mood", "Ready when you are"][index] }
    var detail: String {
        ["Connect to the music you already play on your Mac.",
         "Keep the cover in view, focus on lyrics, or combine both.",
         "Choose how lyrics behave and how much you see.",
         "Your theme applies here as you choose it.",
         "Your choices are saved when you open your player."][index]
    }
}

private extension PlayerLayout {
    var setupDescription: String {
        switch self {
        case .artwork: return "A small cover with controls on hover."
        case .album: return "A clear cover with controls below."
        case .compact: return "Artwork and playback in a slim strip."
        case .lyrics: return "A floating window for the words."
        case .combined: return "Playback and lyrics together."
        case .fullLyrics: return "A separate window for all the lyrics."
        }
    }
}
