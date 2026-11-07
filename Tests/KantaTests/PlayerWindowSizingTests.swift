import AppKit
import SwiftUI
import XCTest
@testable import Kanta

final class PlayerWindowSizingTests: XCTestCase {
    @MainActor
    func testHostedWindowsEnforceMinimumsInBothDimensions() async {
        for layout in PlayerLayout.allCases {
            for arrangement in CombinedArrangement.allCases {
                let minimum = layout.minimumSize(arrangement: arrangement)
                let panel = makePanel(minimum: minimum)
                defer { panel.close() }

                for size in [CGSize(width: 80, height: 40),
                             CGSize(width: 80, height: 600),
                             CGSize(width: 700, height: 40)] {
                    panel.setFrame(CGRect(origin: .zero, size: size), display: false)
                    panel.layoutIfNeeded()
                    XCTAssertGreaterThanOrEqual(panel.frame.width, minimum.width, layout.rawValue)
                    XCTAssertGreaterThanOrEqual(panel.frame.height, minimum.height, layout.rawValue)
                    XCTAssertEqual(panel.minimumPlayerSize, minimum)
                }
            }
        }
    }

    @MainActor
    func testReplacingLayoutUpdatesTheHostConstraintsAndAllowsSmallerHeights() async {
        let panel = makePanel(minimum: PlayerLayout.combined.minimumSize)
        defer { panel.close() }
        let oldHost = panel.contentView!

        panel.contentView = makeHost()
        let minimum = PlayerLayout.compact.minimumSize
        panel.setMinimumPlayerSize(minimum)
        panel.setFrame(CGRect(origin: .zero, size: minimum), display: false)
        panel.layoutIfNeeded()

        XCTAssertEqual(panel.frame.size, minimum)
        XCTAssertTrue(oldHost.constraints.isEmpty)
        XCTAssertEqual(panel.minimumPlayerSize, minimum)
    }

    @MainActor
    func testChangingCombinedArrangementUpdatesExistingConstraints() async {
        let vertical = PlayerLayout.combined.minimumSize(arrangement: .vertical)
        let horizontal = PlayerLayout.combined.minimumSize(arrangement: .horizontal)
        let panel = makePanel(minimum: vertical)
        defer { panel.close() }
        panel.setFrame(CGRect(origin: .zero, size: vertical), display: false)
        panel.layoutIfNeeded()

        panel.setMinimumPlayerSize(horizontal)
        panel.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(panel.frame.width, horizontal.width)
        XCTAssertEqual(panel.minimumPlayerSize, horizontal)

        panel.setMinimumPlayerSize(vertical)
        panel.setFrame(CGRect(origin: .zero, size: vertical), display: false)
        panel.layoutIfNeeded()
        XCTAssertEqual(panel.frame.size, vertical)
    }

    @MainActor
    func testCornerGripUsesRetainedMinimumAfterAutoLayout() async throws {
        for layout in PlayerLayout.allCases {
            let minimum = layout.minimumSize
            let panel = makePanel(minimum: minimum)
            defer { panel.close() }
            panel.contentAspectRatio = layout == .artwork ? CGSize(width: 1, height: 1) : .zero
            let corner = CGPoint(x: panel.frame.width - 4, y: 4)
            let start = panel.convertPoint(toScreen: corner)

            try sendMouse(.leftMouseDown, to: panel, at: start)
            try sendMouse(.leftMouseDragged, to: panel, at: CGPoint(x: start.x - 1000, y: start.y + 1000))
            try sendMouse(.leftMouseUp, to: panel, at: CGPoint(x: start.x - 1000, y: start.y + 1000))
            // Check before Auto Layout can repair an undersized frame from the custom grip.
            XCTAssertEqual(panel.frame.size, minimum, layout.rawValue)
        }
    }

    @MainActor
    private func makePanel(minimum: CGSize) -> PlayerPanel {
        _ = NSApplication.shared
        let panel = PlayerPanel(contentRect: CGRect(x: 100, y: 100, width: 700, height: 600),
                                styleMask: [.borderless, .nonactivatingPanel, .resizable],
                                backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = makeHost()
        panel.setMinimumPlayerSize(minimum)
        panel.layoutIfNeeded()
        return panel
    }

    @MainActor
    private func makeHost() -> NSView {
        let host = NSHostingView(rootView: GeometryReader { _ in Color.clear })
        host.sizingOptions = []
        return host
    }

    @MainActor
    private func sendMouse(_ type: NSEvent.EventType, to panel: PlayerPanel, at screenPoint: CGPoint) throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type,
            location: panel.convertPoint(fromScreen: screenPoint), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        panel.sendEvent(event)
    }
}
