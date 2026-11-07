import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var login: LoginItem
    var configure: (() -> Void)?
    @ViewState private var selection = "General"

    var body: some View {
        TabView(selection: $selection) {
            general.tabItem { Label("General", systemImage: "gearshape") }.tag("General")
            appearance.tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }.tag("Appearance")
            player.tabItem { Label("Player", systemImage: "play.rectangle") }.tag("Player")
            lyrics.tabItem { Label("Lyrics", systemImage: "captions.bubble") }.tag("Lyrics")
        }
        .padding(12)
        .frame(width: 540, height: 495)
        .onAppear { login.refresh() }
    }

    private var general: some View {
        Form {
            Section("Startup") {
                Picker("Playback source", selection: $preferences.values.source) {
                    ForEach(SourcePreference.allCases) { Text($0.title).tag($0) }
                }
                Picker("MiniPlayer layout", selection: $preferences.values.layout) {
                    ForEach(PlayerLayout.miniPlayers) { Text($0.title).tag($0) }
                }
                Toggle("Launch at Login", isOn: Binding(get: { login.enabled }, set: login.setEnabled))
                Toggle("Show Kanta in the Dock", isOn: $preferences.values.showDock)
                if let configure { Button("Run Setup Again…", action: configure) }
                if login.needsApproval {
                    Button("Review Login Items…", action: login.openSettings)
                }
                if let error = login.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Global Keyboard Shortcuts") {
                ForEach(ShortcutAction.allCases, id: \.self) { action in
                    ShortcutRecorder(preferences: preferences, action: action)
                }
                Text("Choose a shortcut with Control, Option, or Command.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var appearance: some View {
        Form {
            Section("Window Style") {
                Picker("Appearance", selection: $preferences.values.theme) {
                    ForEach(Theme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Background style", selection: $preferences.values.background) {
                    ForEach(PlayerBackground.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if preferences.values.background == .glass && !PlayerBackground.supportsGlass {
                    Text("Liquid Glass uses the frosted style on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Tint surfaces with album artwork", isOn: $preferences.values.adaptive)
                settingSlider("Background opacity", value: $preferences.values.backgroundOpacity,
                              range: 0.2...1, step: 0.05, format: .percent)
                settingSlider("Corner radius", value: $preferences.values.cornerRadius,
                              range: 0...32, step: 1, format: .number)
            }
            Section("Interactions") {
                Toggle("Animate layout and lyric transitions", isOn: $preferences.values.animate)
                Toggle("Always show controls on artwork", isOn: $preferences.values.showControls)
            }
        }
        .formStyle(.grouped)
    }

    private var player: some View {
        Form {
            Section("Windows") {
                Toggle("Keep above other windows", isOn: $preferences.values.onTop)
                Toggle("Remember each layout’s size and position", isOn: $preferences.values.rememberFrames)
                Picker("Default window size", selection: $preferences.values.playerScale) {
                    Text("Small").tag(0.85)
                    Text("Medium").tag(1.0)
                    Text("Large").tag(1.20)
                }
                Picker("Combined layout", selection: $preferences.values.arrangement) {
                    ForEach(CombinedArrangement.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Playback") {
                Toggle("Show track information", isOn: $preferences.values.showMetadata)
                Toggle("Show playback progress", isOn: $preferences.values.showProgress)
            }
        }
        .formStyle(.grouped)
    }

    private var lyrics: some View {
        Form {
            Section("Availability") {
                Toggle("Show plain lyrics when live lyrics are unavailable", isOn: $preferences.values.showPlainLyrics)
                Text("Live lyrics stay preferred. A small clock marks unsynced lyrics, which you can scroll to read.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Typography") {
                settingSlider("Font size", value: $preferences.values.lyricSize, range: 13...36, step: 1, format: .number)
                settingSlider("Line spacing", value: $preferences.values.lyricSpacing, range: 0...18, step: 1, format: .number)
                Picker("Alignment", selection: $preferences.values.lyricAlignment) {
                    ForEach(LyricAlignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text("Lyrics Only fits text to the window width and shows more lines as you make it taller.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Highlight", selection: $preferences.values.highlight) {
                    ForEach(Highlight.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Combined MiniPlayer") {
                Picker("Lyric layout", selection: $preferences.values.combinedLyricsLayout) {
                    ForEach(CombinedLyricsLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if preferences.values.combinedLyricsLayout == .compact {
                    Stepper("Preview lines  \(preferences.values.lyricLines)", value: $preferences.values.lyricLines, in: 1...5)
                }
                Text("Compact keeps a small preview. Fill available space uses your font size and shows more lines as the window grows.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Lyrics Overlay") {
                settingSlider("Background opacity", value: $preferences.values.lyricOpacity, range: 0...1, step: 0.05, format: .percent)
                Toggle("Reveal playback controls on hover", isOn: $preferences.values.lyricControls)
                Toggle("Let clicks pass through", isOn: $preferences.values.clickThrough)
                Toggle("Show current line in the menu bar", isOn: $preferences.values.menuLyrics)
            }
            Section("Synchronization") {
                Toggle("Seek when clicking lyrics", isOn: $preferences.values.seekOnLyricClick)
                Stepper(value: $preferences.values.globalOffset, in: -10...10, step: 0.1) {
                    Text("Global offset  \(preferences.values.globalOffset, specifier: "%+.1f") s")
                }
                Button("Reset Global Offset") { preferences.values.globalOffset = 0 }
                    .disabled(preferences.values.globalOffset == 0)
                Text("Adjust and save an individual song’s timing from the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private enum SliderFormat { case number, percent }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                               step: Double, format: SliderFormat) -> some View {
        let displayed = format == .percent ? "\(Int((value.wrappedValue * 100).rounded()))%" : "\(Int(value.wrappedValue.rounded()))"
        return LabeledContent(title) {
            Slider(value: value, in: range, step: step)
                .frame(width: 125)
                .accessibilityLabel(title)
            Text(displayed).foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}

private struct ShortcutRecorder: View {
    @ObservedObject var preferences: Preferences
    let action: ShortcutAction
    @ViewState private var monitor: Any?
    @ViewState private var error: String?

    var body: some View {
        let shortcut = preferences.values.shortcuts[action.rawValue]
        LabeledContent(action.rawValue) {
            Button(monitor == nil ? shortcut?.label ?? "Record…" : "Press keys…") {
                if monitor == nil { record() } else { stop() }
            }
            .accessibilityLabel("Record shortcut for \(action.rawValue)")
            if shortcut != nil {
                Button {
                    stop()
                    preferences.values.shortcuts.removeValue(forKey: action.rawValue)
                } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove shortcut")
                .accessibilityLabel("Remove shortcut for \(action.rawValue)")
            }
        }
        .onDisappear(perform: stop)
        if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
    }

    private func record() {
        error = nil
        let settingsWindow = NSApp.keyWindow
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === settingsWindow else { return event }
            if event.keyCode == kVK_Escape { stop(); return nil }
            let flags = event.modifierFlags
            guard flags.contains(.control) || flags.contains(.option) || flags.contains(.command) else {
                error = "Include Control, Option, or Command."
                return nil
            }
            var modifiers: UInt32 = 0
            var label = ""
            for (flag, code, symbol) in [
                (NSEvent.ModifierFlags.control, controlKey, "⌃"),
                (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")
            ] where flags.contains(flag) {
                modifiers |= UInt32(code)
                label += symbol
            }
            let key = UInt32(event.keyCode)
            if preferences.values.shortcuts.contains(where: {
                $0.key != action.rawValue && $0.value.keyCode == key && $0.value.modifiers == modifiers
            }) {
                error = "That shortcut is already assigned in Kanta."
                return nil
            }
            let name: String
            switch Int(event.keyCode) {
            case kVK_Space: name = "Space"
            case kVK_Return: name = "Return"
            case kVK_LeftArrow: name = "←"
            case kVK_RightArrow: name = "→"
            case kVK_UpArrow: name = "↑"
            case kVK_DownArrow: name = "↓"
            default:
                let text = event.charactersIgnoringModifiers?.uppercased() ?? ""
                name = text.unicodeScalars.allSatisfy { (0xF700...0xF8FF).contains($0.value) } || text.isEmpty
                    ? "Key \(key)" : text
            }
            preferences.values.shortcuts[action.rawValue] = Shortcut(keyCode: key, modifiers: modifiers, label: label + name)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
