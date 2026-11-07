import SwiftUI

// Preserve the property wrapper on SDKs whose State macro is only bundled with Xcode.
typealias ViewState<Value> = SwiftUI.State<Value>

struct PlayerSurface: View {
    let artwork: Artwork?
    let adaptive: Bool
    let style: PlayerBackground
    let shape: RoundedRectangle
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = artwork?.tint ?? SIMD3(0.27, 0.43, 0.40)
        let color = Color(red: tint.x, green: tint.y, blue: tint.z)
        background(tint: color)
            .overlay {
                if adaptive && (style != .glass || !PlayerBackground.supportsGlass) {
                    LinearGradient(
                        colors: scheme == .dark
                            ? [color.opacity(0.58), Color(red: 0.07, green: 0.12, blue: 0.15).opacity(0.55)]
                            : [color.opacity(0.24), color.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 85)
            }
    }

    @ViewBuilder private func background(tint: Color) -> some View {
        switch style {
        case .material:
            shape.fill(.regularMaterial)
        case .solid:
            shape.fill(Color(nsColor: .windowBackgroundColor))
        case .glass:
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular.tint(adaptive ? tint.opacity(0.22) : nil), in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
            #else
            shape.fill(.regularMaterial)
            #endif
        }
    }
}

struct SleeveArtwork: View {
    let artwork: Artwork?
    var corner: CGFloat = 9

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if let artwork {
                Image(decorative: artwork.image, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
            } else {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.16, green: 0.31, blue: 0.30),
                                            Color(red: 0.05, green: 0.10, blue: 0.13)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    RecordGrooves()
                        .stroke(.white.opacity(0.13), lineWidth: 0.8)
                        .rotationEffect(.degrees(-15))
                    Image(systemName: "music.note")
                        .font(.system(size: min(size.width, size.height) * 0.24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }
}

private struct RecordGrooves: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let extent = max(rect.width, rect.height)
        var path = Path()
        for index in 1...12 {
            let radius = CGFloat(index) * extent * 0.066
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2))
        }
        return path
    }
}

struct Eyebrow: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(title.uppercased()).tracking(1.5)
        }
        .font(.system(size: 10, weight: .semibold))
    }
}

struct TrackDetails: View {
    let track: Track
    var size: CGFloat = 15
    var showAlbum = false
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(track.title)
                .font(.system(size: size, weight: .semibold))
                .lineLimit(1)
            Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                .font(.system(size: size * 0.80, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if showAlbum && !track.album.isEmpty {
                Text(track.album)
                    .font(.system(size: size * 0.70))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
        .help([track.title, track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
    }
}

struct PlayerEmptyState: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 11) {
                Image(systemName: model.availability.permissionRequired ? "lock.shield" : "music.note")
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 50, height: 50)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityHidden(true)
                VStack(spacing: 5) {
                    Eyebrow(title: "Kanta")
                        .foregroundStyle(.secondary)
                    Text(model.availability.title)
                        .font(.system(.headline))
                    Text(model.availability.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if model.availability.permissionRequired {
                    Button("Open Automation Settings", action: openAutomationSettings)
                        .controlSize(.small)
                }
            }
            HStack(spacing: 12) {
                Image(systemName: model.availability.permissionRequired ? "lock.shield" : "music.note")
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.availability.title).font(.headline)
                    Text(model.availability.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if model.availability.permissionRequired {
                    Button(action: openAutomationSettings) { Image(systemName: "gearshape") }
                        .accessibilityLabel("Open Automation Settings")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

private extension PlayerAvailability {
    var permissionRequired: Bool {
        if case .permissionDenied = self { return true }
        return false
    }
}
