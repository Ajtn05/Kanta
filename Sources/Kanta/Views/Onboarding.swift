import SwiftUI

struct Onboarding: View {
    @ObservedObject var login: LoginItem
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(spacing: 13) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Kanta").font(.system(size: 24, weight: .semibold))
                    Text("Your music, close by.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                tip("Start with Spotify or Apple Music", "Open either music app and play a song.")
                tip("Allow Automation when asked",
                    "macOS uses this permission to let Kanta read and control playback.")
                tip("Find Kanta in the menu bar",
                    "Switch layouts, open lyrics, and manage your MiniPlayer.")
            }
            Divider()
            Toggle("Launch at Login", isOn: Binding(get: { login.enabled }, set: login.setEnabled))
                .font(.callout)
            if let error = login.error {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Get Started", action: finish)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 410)
    }

    private func tip(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
