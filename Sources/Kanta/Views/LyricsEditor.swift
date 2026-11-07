import SwiftUI

struct LyricsEditor: View {
    let track: Track
    @ObservedObject var model: PlayerModel
    let close: () -> Void
    @ViewState private var input = ""
    @ViewState private var hasOverride = false
    @ViewState private var loaded = false
    @ViewState private var busy = false
    @ViewState private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Eyebrow(title: "Local lyrics", icon: "text.quote").foregroundStyle(.secondary)
            TrackDetails(track: track, size: 21, showAlbum: true)
            Text("Paste plain lyrics or LRC with timestamps like [01:24.50]. Saved lyrics stay on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $input)
                .font(.system(.callout))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Lyrics text")
                .disabled(!loaded || busy)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Search Again") {
                    model.loadLyrics(refresh: true)
                    close()
                }
                .disabled(model.track?.identity != track.identity || hasOverride || busy)
                if hasOverride {
                    Button("Remove Override", role: .destructive) {
                        edit { try await model.removeLyrics(for: track) }
                    }
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button("Save Lyrics") {
                    edit { try await model.saveLyrics(input, for: track) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!loaded || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
            }
        }
        .padding(22)
        .frame(width: 520, height: 372)
        .task {
            if let text = await model.overrideText(for: track) {
                input = text
                hasOverride = true
            }
            loaded = true
        }
    }

    private func edit(_ operation: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            do {
                try await operation()
                close()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}
