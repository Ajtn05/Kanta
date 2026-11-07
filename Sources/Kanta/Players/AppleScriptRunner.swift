import AppKit
import Foundation

/// osascript keeps synchronous Apple Events and consent dialogs off the UI thread.
final class AppleScriptRunner {
    private let queue = DispatchQueue(label: "Kanta.AppleScript", qos: .userInitiated)

    func run(_ body: String, in source: MusicSource) async throws -> String {
        let script = Self.wrapped(body, in: source)
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try Self.execute(script, source: source) })
            }
        }
    }

    static func wrapped(_ body: String, in source: MusicSource) -> String {
        """
        set targetID to "\(source.bundleID)"
        if application id targetID is not running then error "Player closed" number -600
        with timeout of 3 seconds
            tell application id targetID
        \(body)
            end tell
        end timeout
        """
    }

    private static func execute(_ script: String, source: MusicSource) throws -> String {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty else {
            throw PlayerFailure.notRunning
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = output
        process.standardError = output
        try process.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            if text.contains("(-1743)") || text.contains("(-10004)") { throw PlayerFailure.permissionDenied }
            if text.contains("(-600)") { throw PlayerFailure.notRunning }
            if text.contains("(-1728)") || text.contains("(-10006)") { throw PlayerFailure.noTrack }
            throw PlayerFailure.unavailable
        }
        return text.hasSuffix("\n") ? String(text.dropLast()) : text
    }
}
