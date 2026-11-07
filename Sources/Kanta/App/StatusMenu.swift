import AppKit

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private weak var app: KantaApp?
    private var timer: Timer?
    private var line = ""

    init(app: KantaApp) {
        self.app = app
        super.init()
        item.button?.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Kanta")
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Kanta"
        menu.delegate = self
        item.menu = menu
    }

    func configureLyrics(_ enabled: Bool) {
        if enabled {
            guard timer == nil else { return }
            let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(updateTitle), userInfo: nil, repeats: true)
            timer.tolerance = 0.06
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            updateTitle()
        } else {
            timer?.invalidate()
            timer = nil
            setLine("")
        }
    }

    @objc private func updateTitle() {
        guard let app, let lyrics = app.model.lyrics.lyrics,
              let index = lyrics.activeIndex(at: app.model.position, offset: app.preferences.offset(for: app.model.track))
        else { setLine(""); return }
        let text = lyrics.lines[index].text
        let oneLine = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard oneLine != line else { return }
        setLine(oneLine)
    }

    private func setLine(_ text: String) {
        guard text != line, let button = item.button else { return }
        line = text
        let font = NSFont.menuBarFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var visible = ""
        for character in text {
            let candidate = visible + String(character)
            if (candidate as NSString).size(withAttributes: attributes).width > 158 { break }
            visible = candidate
        }
        if visible.count < text.count { visible += "…" }
        button.title = visible
        button.imagePosition = visible.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = text.isEmpty ? "Kanta" : text
        button.setAccessibilityLabel(text.isEmpty ? "Kanta" : "Kanta, " + text)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let app else { return }
        let preferences = app.preferences
        let model = app.model
        let options = preferences.values
        menu.removeAllItems()
        let heading = NSMenuItem(title: model.track?.title ?? "Kanta", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        if let track = model.track {
            let state: String
            switch model.playback?.state {
            case .playing: state = track.source.title
            case .paused: state = "Paused"
            default: state = "Stopped"
            }
            let byline = [track.artist, state].filter { !$0.isEmpty }.joined(separator: " · ")
            menu.addItem(NSMenuItem(title: byline, action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(item(app.windows.miniVisible ? "Hide MiniPlayer" : "Show MiniPlayer",
                          icon: "macwindow") { [weak app] in app?.windows.toggleMini() })
        let layouts = NSMenu()
        for layout in PlayerLayout.miniPlayers {
            let row = item(layout.title, icon: layout.icon) { [weak app] in app?.windows.select(layout) }
            row.state = options.layout == layout ? .on : .off
            layouts.addItem(row)
        }
        menu.addItem(submenu("Layout", layouts, icon: "rectangle.split.2x1"))
        let sources = NSMenu()
        for source in SourcePreference.allCases {
            let row = item(source.title) { preferences.values.source = source }
            row.state = options.source == source ? .on : .off
            sources.addItem(row)
        }
        menu.addItem(submenu("Playback Source", sources, icon: "music.note"))
        menu.addItem(.separator())
        menu.addItem(item("Show Full Lyrics", icon: "text.alignleft") { [weak app] in app?.windows.showFull() })
        let editor = item("Find or Paste Lyrics…", icon: "text.quote") { [weak app] in app?.showLyricsEditor() }
        editor.isEnabled = model.track != nil
        menu.addItem(editor)
        if let track = model.track {
            let sync = NSMenu()
            let offset = preferences.offset(for: track)
            sync.addItem(NSMenuItem(title: String(format: "Current offset  %+.2f s", offset), action: nil, keyEquivalent: ""))
            sync.addItem(.separator())
            for (title, shift) in [("Earlier by 0.10 s", 0.1), ("Later by 0.10 s", -0.1),
                                   ("Earlier by 0.25 s", 0.25), ("Later by 0.25 s", -0.25)] {
                sync.addItem(item(title) { preferences.adjustOffset(for: track, by: shift) })
            }
            sync.addItem(item("Reset Track Offset") { preferences.adjustOffset(for: track, by: nil) })
            menu.addItem(submenu("Adjust Synchronization", sync, icon: "clock"))
        }
        menu.addItem(.separator())
        let top = item("Always on Top") { preferences.values.onTop.toggle() }
        top.state = options.onTop ? .on : .off
        menu.addItem(top)
        let clicks = item("Lyrics Click-Through") { preferences.values.clickThrough.toggle() }
        clicks.state = options.clickThrough ? .on : .off
        menu.addItem(clicks)
        let menuLyrics = item("Show Lyrics in Menu Bar") { preferences.values.menuLyrics.toggle() }
        menuLyrics.state = options.menuLyrics ? .on : .off
        menu.addItem(menuLyrics)
        menu.addItem(.separator())
        menu.addItem(item("Preferences…", key: ",", icon: "gearshape") { [weak app] in app?.showSettings() })
        menu.addItem(item("Run Setup…", icon: "slider.horizontal.3") { [weak app] in app?.showOnboarding() })
        let login = item("Launch at Login") { [weak app] in
            guard let app else { return }
            app.login.setEnabled(!app.login.enabled)
        }
        app.login.refresh()
        login.state = app.login.enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Quit Kanta", key: "q") { NSApp.terminate(nil) })
        menu.autoenablesItems = false
    }

    private func item(_ title: String, key: String = "", icon: String? = nil, _ action: @escaping () -> Void) -> NSMenuItem {
        let row = ActionMenuItem(title: title, action: #selector(ActionMenuItem.invoke), keyEquivalent: key)
        row.target = row
        row.callback = action
        if let icon { row.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) }
        return row
    }

    private func submenu(_ title: String, _ menu: NSMenu, icon: String) -> NSMenuItem {
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        row.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        row.submenu = menu
        return row
    }
}

private final class ActionMenuItem: NSMenuItem {
    var callback: (() -> Void)?
    @objc func invoke() { callback?() }
}
