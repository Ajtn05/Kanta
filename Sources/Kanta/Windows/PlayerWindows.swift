import AppKit
import SwiftUI

@MainActor
final class PlayerWindows: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private let model: PlayerModel
    private var mini: PlayerPanel?
    private var full: PlayerPanel?
    private var miniLayout: PlayerLayout?
    private var restoring = false
    var findLyrics: (() -> Void)?
    var openPreferences: (() -> Void)?

    var miniVisible: Bool { mini?.isVisible == true }

    init(model: PlayerModel, preferences: Preferences) {
        self.model = model
        self.preferences = preferences
        super.init()
    }

    func toggleMini() {
        if miniVisible { mini?.orderOut(nil) } else { showMini() }
    }

    func showMini() {
        let layout = preferences.values.layout
        if miniLayout != layout || mini == nil { switchMini(to: layout) }
        applySettings()
        mini?.orderFrontRegardless()
    }

    func select(_ layout: PlayerLayout) {
        preferences.select(layout)
        showMini()
    }

    func preferencesChanged(from previous: SettingsValues) {
        let options = preferences.values
        if mini != nil && miniLayout != options.layout { switchMini(to: options.layout) }
        if previous.playerScale != options.playerScale, let mini, let miniLayout {
            let target = defaultFrame(for: miniLayout, near: mini.frame, scale: options.playerScale)
            let frame = WindowPlacement.fitted(target, to: NSScreen.screens.map(\.visibleFrame),
                                               minimum: minimumSize(for: miniLayout), square: miniLayout == .artwork)
            mini.setFrame(frame, display: true)
        }
        applySettings()
        if previous.arrangement != options.arrangement, let mini, let miniLayout {
            fitExisting(mini, layout: miniLayout)
        }
    }

    func showFull() {
        if full == nil {
            let window = makePanel(for: .fullLyrics)
            full = window
            restore(window, for: .fullLyrics, near: mini?.frame, animate: false)
        }
        applySettings()
        full?.orderFrontRegardless()
    }

    func restoreVisibleFrames() {
        if let mini, let miniLayout { fitExisting(mini, layout: miniLayout) }
        if let full { fitExisting(full, layout: .fullLyrics) }
    }

    private func fitExisting(_ panel: PlayerPanel, layout: PlayerLayout) {
        let fitted = WindowPlacement.fitted(panel.frame, to: NSScreen.screens.map(\.visibleFrame),
                                            minimum: minimumSize(for: layout), square: layout == .artwork)
        if fitted != panel.frame {
            // Preserve the old placement while a display is temporarily disconnected.
            restoring = true
            panel.setFrame(fitted, display: true)
            restoring = false
        }
    }

    private func switchMini(to layout: PlayerLayout) {
        let panel = mini ?? makePanel(for: layout)
        let oldFrame = mini?.frame
        if let miniLayout, let oldFrame { preferences.saveFrame(oldFrame, for: miniLayout) }
        let animated = panel.isVisible && preferences.values.animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        miniLayout = layout
        mini = panel
        panel.title = layout.title
        panel.contentAspectRatio = layout == .artwork ? CGSize(width: 1, height: 1) : .zero
        restore(panel, for: layout, near: oldFrame, animate: animated)
        configureContent(panel, layout: layout)
    }

    private func makePanel(for layout: PlayerLayout) -> PlayerPanel {
        let window = PlayerPanel(
            contentRect: CGRect(origin: .zero, size: layout.suggestedSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered, defer: false
        )
        window.title = layout.title
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.delegate = self
        configureContent(window, layout: layout)
        return window
    }

    private func configureContent(_ panel: PlayerPanel, layout: PlayerLayout) {
        let host = NSHostingView(rootView: PlayerRoot(
            layout: layout, model: model, preferences: preferences,
            select: { [weak self] in self?.select($0) },
            fullLyrics: { [weak self] in self?.showFull() },
            close: { [weak panel] in panel?.orderOut(nil) },
            findLyrics: { [weak self] in self?.findLyrics?() },
            settings: { [weak self] in self?.openPreferences?() },
            move: { [weak panel] in panel?.moveFromBackground(done: $0) }
        ))
        // SwiftUI's ideal size must not override the user's saved window dimensions.
        host.sizingOptions = []
        panel.contentView = host
        panel.setMinimumPlayerSize(minimumSize(for: layout))
        panel.invalidateShadow()
    }

    private func applySettings() {
        let options = preferences.values
        for panel in [mini, full].compactMap({ $0 }) {
            panel.setMinimumPlayerSize(minimumSize(for: panel === full ? .fullLyrics : (miniLayout ?? options.layout)))
            panel.appearance = options.theme.appearance
            panel.level = options.onTop ? .floating : .normal
            panel.ignoresMouseEvents = panel === mini && miniLayout == .lyrics && options.clickThrough
            panel.hasShadow = !(panel === mini && miniLayout == .lyrics && options.lyricOpacity < 0.12)
            panel.invalidateShadow()
        }
    }

    private func minimumSize(for layout: PlayerLayout) -> CGSize {
        layout.minimumSize(arrangement: preferences.values.arrangement)
    }

    private func restore(_ window: PlayerPanel, for layout: PlayerLayout, near old: CGRect?, animate: Bool) {
        let scale = layout == .fullLyrics ? 1 : preferences.values.playerScale
        let target = preferences.frame(for: layout) ?? defaultFrame(for: layout, near: old, scale: scale)
        let frame = WindowPlacement.fitted(target, to: NSScreen.screens.map(\.visibleFrame),
                                           minimum: minimumSize(for: layout), square: layout == .artwork)
        restoring = true
        window.setFrame(frame, display: true, animate: animate)
        restoring = false
    }

    private func defaultFrame(for layout: PlayerLayout, near old: CGRect?, scale: Double) -> CGRect {
        let size = CGSize(width: layout.suggestedSize.width * scale, height: layout.suggestedSize.height * scale)
        let anchor = old.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let top = old?.maxY ?? ((screen?.visibleFrame.maxY ?? 760) - 52)
        var right = old?.maxX ?? ((screen?.visibleFrame.maxX ?? 1100) - 26)
        if layout == .fullLyrics, let old, let screen,
           old.minX - 14 - size.width >= screen.visibleFrame.minX {
            right = old.minX - 14
        }
        return CGRect(x: right - size.width, y: top - size.height, width: size.width, height: size.height)
    }

    func windowDidMove(_ notification: Notification) { saveFrame(notification) }
    func windowDidResize(_ notification: Notification) { saveFrame(notification) }

    private func saveFrame(_ notification: Notification) {
        guard !restoring, let panel = notification.object as? PlayerPanel else { return }
        let layout = panel === full ? .fullLyrics : miniLayout
        if let layout { preferences.saveFrame(panel.frame, for: layout) }
    }
}

enum WindowPlacement {
    static func fitted(_ frame: CGRect, to screens: [CGRect], minimum: CGSize, square: Bool) -> CGRect {
        guard frame.width.isFinite, frame.height.isFinite, frame.minX.isFinite, frame.minY.isFinite else {
            return fitted(CGRect(origin: .zero, size: minimum), to: screens, minimum: minimum, square: square)
        }
        guard let screen = screens.max(by: { intersectionArea(frame, $0) < intersectionArea(frame, $1) }) else {
            return frame
        }
        let width = min(screen.width, max(minimum.width, frame.width))
        let height = min(screen.height, max(minimum.height, frame.height))
        let size = square ? CGSize(width: min(width, height), height: min(width, height)) : CGSize(width: width, height: height)
        let x = min(max(screen.minX, frame.minX), screen.maxX - size.width)
        let y = min(max(screen.minY, frame.maxY - size.height), screen.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let overlap = lhs.intersection(rhs)
        return overlap.isNull ? 0 : overlap.width * overlap.height
    }
}

final class PlayerPanel: NSPanel {
    private(set) var minimumPlayerSize: CGSize = .zero
    private var minimumWidthConstraint: NSLayoutConstraint?
    private var minimumHeightConstraint: NSLayoutConstraint?
    private var resizeStart: (frame: CGRect, pointer: NSPoint)?
    private var moveStart: (origin: CGPoint, pointer: NSPoint)?
    private var eventPointer: NSPoint?
    private var resizing = false

    func setMinimumPlayerSize(_ size: CGSize) {
        minimumPlayerSize = size
        guard let contentView else { return }
        // AppKit ignores contentMinSize under Auto Layout and can reset it to zero.
        // Constrain the host for native edge resizing, and retain the same limit for the grip.
        if minimumWidthConstraint?.firstItem as? NSView !== contentView {
            NSLayoutConstraint.deactivate([minimumWidthConstraint, minimumHeightConstraint].compactMap { $0 })
            minimumWidthConstraint = contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: size.width)
            minimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: size.height)
            NSLayoutConstraint.activate([minimumWidthConstraint, minimumHeightConstraint].compactMap { $0 })
        } else {
            minimumWidthConstraint?.constant = size.width
            minimumHeightConstraint?.constant = size.height
        }
    }

    override func sendEvent(_ event: NSEvent) {
        if [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type) {
            // Delivered event coordinates also work during rapid and synthesized drags.
            let pointer = convertPoint(toScreen: event.locationInWindow)
            if event.type != .leftMouseUp { eventPointer = pointer }
            if event.type == .leftMouseDown {
                moveStart = (frame.origin, pointer)
                resizeStart = (frame, pointer)
                let point = event.locationInWindow
                let fromRight = frame.width - point.x
                let corner = CGRect(x: frame.width - 24, y: 0, width: 24, height: 24)
                resizing = corner.contains(point) && fromRight + point.y < 28
                if resizing { return }
            } else if resizing {
                resizeFromCorner(square: contentAspectRatio == CGSize(width: 1, height: 1))
                if event.type == .leftMouseUp {
                    resizing = false
                    resizeStart = nil
                    moveStart = nil
                }
                return
            }
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.20 }

    func moveFromBackground(done: Bool) {
        if done {
            moveStart = nil
            return
        }
        guard let start = moveStart, let pointer = eventPointer else { return }
        setFrameOrigin(NSPoint(x: start.origin.x + pointer.x - start.pointer.x,
                               y: start.origin.y + pointer.y - start.pointer.y))
    }

    private func resizeFromCorner(square: Bool) {
        guard let start = resizeStart, let pointer = eventPointer else { return }
        let bounds = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let dx = pointer.x - start.pointer.x
        let dy = start.pointer.y - pointer.y
        let maxWidth = max(minimumPlayerSize.width, bounds.maxX - start.frame.minX)
        let maxHeight = max(minimumPlayerSize.height, start.frame.maxY - bounds.minY)
        var width = min(maxWidth, max(minimumPlayerSize.width, start.frame.width + dx))
        var height = min(maxHeight, max(minimumPlayerSize.height, start.frame.height + dy))
        if square {
            let delta = abs(dx) >= abs(dy) ? dx : dy
            width = min(maxWidth, maxHeight, max(minimumPlayerSize.width, minimumPlayerSize.height, start.frame.width + delta))
            height = width
        }
        setFrame(CGRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height), display: true)
    }
}
