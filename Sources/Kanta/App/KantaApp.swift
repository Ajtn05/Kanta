import AppKit
import Combine
import SwiftUI

@main
struct Kanta {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = KantaApp()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class KantaApp: NSObject, NSApplicationDelegate {
    let preferences: Preferences
    let model: PlayerModel
    let windows: PlayerWindows
    let login = LoginItem()
    private let demo: Bool
    private var status: StatusMenu?
    private var shortcuts: GlobalShortcuts?
    private var settingsObserver: AnyCancellable?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var auxiliary: [String: NSWindow] = [:]

    override init() {
        demo = CommandLine.arguments.contains("--demo")
        preferences = demo ? Preferences(defaults: nil) : Preferences()
        if demo {
            model = PlayerModel(providers: [DemoProvider()], useSystemAvailability: false, demoLyrics: DemoProvider.lyrics)
        } else {
            let runner = AppleScriptRunner()
            model = PlayerModel(providers: [SpotifyProvider(runner: runner), AppleMusicProvider(runner: runner)])
        }
        windows = PlayerWindows(model: model, preferences: preferences)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = preferences.values
        NSApp.setActivationPolicy(options.showDock ? .regular : .accessory)
        setMainMenu()
        status = StatusMenu(app: self)
        status?.configureLyrics(options.menuLyrics)
        shortcuts = GlobalShortcuts { [weak self] action in self?.handle(action) }
        _ = shortcuts?.configure(options.shortcuts)

        windows.findLyrics = { [weak self] in self?.showLyricsEditor() }
        windows.openPreferences = { [weak self] in self?.showSettings() }

        var previous = options
        settingsObserver = preferences.$values.dropFirst().sink { [weak self] _ in
            // @Published delivers in willSet; read the committed value on the next main turn.
            Task { @MainActor [weak self] in
                guard let self else { return }
                let current = self.preferences.values
                self.apply(current, previous: previous)
                previous = current
            }
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let process = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      MusicSource.allCases.contains(where: { $0.bundleID == process.bundleIdentifier }) else { return }
                Task { @MainActor [weak self] in self?.model.refresh() }
            })
        }

        if (options.hasOnboarded || demo) && !CommandLine.arguments.contains("--setup") {
            start()
            if demo && CommandLine.arguments.contains("--full-lyrics") { windows.showFull() }
        } else {
            showOnboarding()
        }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        windows.restoreVisibleFrames()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        login.refresh()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !preferences.values.hasOnboarded && !demo { showOnboarding() } else { windows.showMini() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        status?.configureLyrics(false)
        model.stop()
        shortcuts = nil
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }

    private func start() {
        if demo, let index = CommandLine.arguments.firstIndex(of: "--layout"),
           CommandLine.arguments.indices.contains(index + 1),
           let layout = PlayerLayout(rawValue: CommandLine.arguments[index + 1]) {
            preferences.select(layout)
        }
        model.start(source: preferences.values.source)
        windows.showMini()
    }

    private func handle(_ action: ShortcutAction) {
        switch action {
        case .toggle: windows.toggleMini()
        case .cycle:
            preferences.cycleLayout()
            windows.showMini()
        case .full: windows.showFull()
        }
    }

    private func apply(_ options: SettingsValues, previous: SettingsValues) {
        windows.preferencesChanged(from: previous)
        if options.source != previous.source { model.changeSource(to: options.source) }
        if options.showDock != previous.showDock { NSApp.setActivationPolicy(options.showDock ? .regular : .accessory) }
        if options.menuLyrics != previous.menuLyrics { status?.configureLyrics(options.menuLyrics) }
        if options.theme != previous.theme {
            auxiliary.values.forEach { $0.appearance = options.theme.appearance }
        }
        if options.shortcuts != previous.shortcuts, let shortcuts {
            let rejected = shortcuts.configure(options.shortcuts)
            if !rejected.isEmpty {
                let alert = NSAlert()
                alert.messageText = "A global shortcut is unavailable"
                alert.informativeText = rejected.joined(separator: ", ") + ". Choose a different key combination."
                if let settings = auxiliary["settings"], settings.isVisible { alert.beginSheetModal(for: settings) }
                rejected.forEach { preferences.values.shortcuts.removeValue(forKey: $0) }
            }
        }
    }

    func showSettings() {
        showWindow("settings", title: "Kanta Preferences", content: SettingsView(preferences: preferences, login: login,
            configure: { [weak self] in self?.showOnboarding() }))
    }

    func showOnboarding() {
        if let welcome = auxiliary["welcome"], welcome.isVisible {
            welcome.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        auxiliary.removeValue(forKey: "welcome")
        showWindow("welcome", title: "Welcome to Kanta", content: Onboarding(preferences: preferences, login: login) { [weak self] in
            guard let self else { return }
            self.preferences.values.hasOnboarded = true
            self.auxiliary["welcome"]?.close()
            self.start()
        })
    }

    func showLyricsEditor() {
        guard let track = model.track else { return }
        if let window = auxiliary["lyrics"], window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        auxiliary.removeValue(forKey: "lyrics")
        showWindow("lyrics", title: "Find or Paste Lyrics", content: LyricsEditor(track: track, model: model) { [weak self] in
            self?.auxiliary["lyrics"]?.close()
        })
    }

    private func showWindow<Content: View>(_ id: String, title: String, content: Content) {
        if auxiliary[id] == nil {
            let controller = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = title
            window.isReleasedWhenClosed = false
            window.appearance = preferences.values.theme.appearance
            window.center()
            auxiliary[id] = window
        }
        auxiliary[id]?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setMainMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        bar.addItem(appItem)
        let menu = NSMenu()
        appItem.submenu = menu
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Kanta", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        bar.addItem(editItem)
        editItem.submenu = edit
        NSApp.mainMenu = bar
    }

    @objc private func openSettings() { showSettings() }
}
