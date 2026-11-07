import CryptoKit
import Foundation

struct LocalFiles: Sendable {
    let directory: URL

    static var cache: LocalFiles {
        LocalFiles(directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kanta", isDirectory: true))
    }

    static var support: LocalFiles {
        LocalFiles(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kanta", isDirectory: true))
    }

    func path(_ folder: String, _ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(folder, isDirectory: true).appendingPathComponent(digest)
    }

    func read(_ folder: String, _ key: String) -> Data? {
        try? Data(contentsOf: path(folder, key), options: .mappedIfSafe)
    }

    func write(_ data: Data, folder: String, key: String) throws {
        let url = path(folder, key)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    func remove(_ folder: String, _ key: String) throws {
        do {
            try FileManager.default.removeItem(at: path(folder, key))
        } catch CocoaError.fileNoSuchFile {
            // Removing an already absent override succeeds.
        }
    }

    func prune(_ folder: String, maximumBytes: Int) {
        let root = directory.appendingPathComponent(folder, isDirectory: true)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles
        ) else { return }
        let files = urls.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: keys), let size = values.fileSize else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, size)
        }.sorted { $0.1 > $1.1 }
        var remaining = maximumBytes
        for (url, _, size) in files {
            if size <= remaining {
                remaining -= size
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
