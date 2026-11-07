import SwiftUI

struct Transport: View {
    @ObservedObject var model: PlayerModel
    var size: CGFloat = 30
    var featured = false

    var body: some View {
        HStack(spacing: featured ? 12 : 3) {
            control("backward.fill", "Previous Track", command: .previous)
            control(model.isPlaying ? "pause.fill" : "play.fill",
                    model.isPlaying ? "Pause" : "Play", command: .toggle, primary: true)
            control("forward.fill", "Next Track", command: .next)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Playback controls")
    }

    private func control(_ icon: String, _ label: String, command: PlayerCommand, primary: Bool = false) -> some View {
        Button { model.send(command) } label: {
            Image(systemName: icon)
                .font(.system(size: size * (primary ? 0.55 : 0.40), weight: .semibold))
                .frame(width: size * (primary && featured ? 1.30 : 1), height: size * (primary && featured ? 1.30 : 1))
                .background {
                    if primary {
                        Circle().fill(.primary.opacity(featured ? 0.19 : 0.10))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(TransportButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TransportButton(configuration: configuration)
    }

    private struct TransportButton: View {
        let configuration: Configuration
        @ViewState private var hovered = false
        @Environment(\.accessibilityReduceMotion) private var reducedMotion

        var body: some View {
            configuration.label
                .background(.primary.opacity(hovered ? 0.11 : 0), in: Circle())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hovering in
                    withAnimation(reducedMotion ? nil : .easeOut(duration: 0.16)) { hovered = hovering }
                }
        }
    }
}

struct ProgressStrip: View {
    let playback: Playback
    let seek: (Double) -> Void
    var labels = false
    var thickness: CGFloat = 3
    @ViewState private var dragPosition: Double?
    @ViewState private var hovered = false

    var body: some View {
        if playback.track.duration > 0 {
            TimelineView(.animation(minimumInterval: 0.10, paused: playback.state != .playing)) { _ in
                let duration = playback.track.duration
                let position = dragPosition ?? playback.position()
                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let ratio = min(1, max(0, position / duration))
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.17))
                            Capsule().fill(.primary.opacity(0.82)).frame(width: width * ratio)
                        }
                        .frame(height: hovered || dragPosition != nil ? thickness + 2 : thickness)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onHover { hovered = $0 }
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { dragPosition = value(at: $0.location.x, width: width, duration: duration) }
                            .onEnded {
                                seek(value(at: $0.location.x, width: width, duration: duration))
                                dragPosition = nil
                            })
                    }
                    .frame(height: 13)
                    if labels {
                        HStack {
                            Text(format(position))
                            Spacer()
                            Text(format(duration))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Playback progress")
                .accessibilityValue("\(format(position)) of \(format(duration))")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: seek(min(duration, position + 5))
                    case .decrement: seek(max(0, position - 5))
                    @unknown default: break
                    }
                }
            }
        }
    }

    private func value(at x: CGFloat, width: CGFloat, duration: Double) -> Double {
        min(1, max(0, x / max(1, width))) * duration
    }

    private func format(_ duration: Double) -> String {
        let seconds = Int(min(99_999_999, max(0, duration)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
