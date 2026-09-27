import Foundation

public final class TimelineStore: EventRecording {
    private let lock = NSLock()
    private let fileURL: URL?
    private var events: [TimelineEvent] = []
    private let maximumStoredEvents: Int

    public init(
        fileURL: URL? = TimelineStore.defaultFileURL(),
        maximumStoredEvents: Int = 500
    ) {
        self.fileURL = fileURL
        self.maximumStoredEvents = max(1, maximumStoredEvents)
        Self.migrateLegacyDirectoryIfNeeded()
        load()
    }

    public func append(_ event: TimelineEvent) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
        if events.count > maximumStoredEvents {
            events.removeFirst(events.count - maximumStoredEvents)
        }
        if let fileURL {
            let line = try? Self.encoder.encode(event)
            if let line {
                Self.appendLine(line, to: fileURL)
            }
        }
    }

    public func allEvents(limit: Int = 500) -> [TimelineEvent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(events.sorted { $0.timestamp < $1.timestamp }.suffix(max(0, limit)))
    }

    public func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let text = String(data: data, encoding: .utf8) ?? ""
        let decoder = Self.decoder
        var loaded = text.split(whereSeparator: \.isNewline).compactMap { line -> TimelineEvent? in
            try? decoder.decode(TimelineEvent.self, from: Data(line.utf8))
        }
        if loaded.count > maximumStoredEvents {
            loaded.removeFirst(loaded.count - maximumStoredEvents)
        }
        lock.lock()
        events = loaded
        lock.unlock()
    }

    public static func defaultFileURL() -> URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return base?.appendingPathComponent("NetDoctor", isDirectory: true)
            .appendingPathComponent("timeline.jsonl")
    }

    public static func migrateLegacyDirectoryIfNeeded() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldDir = appSupport.appendingPathComponent("NetworkConsoleLite")
        let newDir = appSupport.appendingPathComponent("NetDoctor")
        guard fm.fileExists(atPath: oldDir.path) else { return }
        if !fm.fileExists(atPath: newDir.path) {
            try? fm.moveItem(at: oldDir, to: newDir)
        } else {
            let oldFile = oldDir.appendingPathComponent("timeline.jsonl")
            let newFile = newDir.appendingPathComponent("timeline.jsonl")
            if fm.fileExists(atPath: oldFile.path) && !fm.fileExists(atPath: newFile.path) {
                try? fm.moveItem(at: oldFile, to: newFile)
            }
        }
    }

    private static func appendLine(_ line: Data, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line + Data([0x0A]))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
