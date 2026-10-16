import Combine
import Foundation

/// All notes live in ~/Library/Application Support/GranolaIsDead/notes as one
/// JSON file each (no account, no sync, nothing leaves the Mac). Writes are
/// debounced per note and land atomically.
@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published private(set) var notes: [Note] = []
    @Published private(set) var folders: [Folder] = []

    private let dir: URL
    private let foldersURL: URL
    private var pendingWrites: [UUID: DispatchWorkItem] = [:]
    private let io = DispatchQueue(label: "com.muckstack.granolaisdead.notes-io", qos: .utility)

    init(root: URL = Paths.support) {
        dir = root.appendingPathComponent("notes", isDirectory: true)
        foldersURL = root.appendingPathComponent("folders.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }()

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        notes = files.filter { $0.pathExtension == "json" }
            .compactMap { try? Self.decoder.decode(Note.self, from: Data(contentsOf: $0)) }
            .sorted { $0.sortDate > $1.sortDate }
        if let data = try? Data(contentsOf: foldersURL), let f = try? Self.decoder.decode([Folder].self, from: data) { folders = f }
    }

    func note(_ id: UUID) -> Note? { notes.first { $0.id == id } }

    @discardableResult
    func create(_ configure: (inout Note) -> Void = { _ in }) -> Note {
        var n = Note()
        configure(&n)
        notes.insert(n, at: 0)
        persist(n, immediately: true)
        return n
    }

    /// Mutate a note in place; the write is debounced (0.4s) unless `immediately`.
    func update(_ id: UUID, immediately: Bool = false, _ change: (inout Note) -> Void) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        var n = notes[i]
        change(&n)
        guard n != notes[i] else { return }
        n.updatedAt = Date()
        notes[i] = n
        persist(n, immediately: immediately)
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        pendingWrites[id]?.cancel(); pendingWrites[id] = nil
        let url = fileURL(id)
        io.async { try? FileManager.default.removeItem(at: url) }
        Recordings.delete(noteID: id)
    }

    /// Write every pending change. `sync` waits for the disk (quit path).
    func flushAll(sync: Bool = false) {
        for (id, work) in pendingWrites { work.cancel(); if let n = note(id) { write(n) } }
        pendingWrites.removeAll()
        if sync { io.sync {} }
    }

    // MARK: Folders

    @discardableResult
    func createFolder(_ name: String) -> Folder {
        let f = Folder(name: name.isEmpty ? "New folder" : name)
        folders.append(f); saveFolders(); return f
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[i].name = name; saveFolders()
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }; saveFolders()
        for n in notes where n.folderID == id { update(n.id) { $0.folderID = nil } }
    }

    private func saveFolders() {
        guard let data = try? Self.encoder.encode(folders) else { return }
        let url = foldersURL
        io.async { try? data.write(to: url, options: .atomic) }
    }

    // MARK: IO

    private func fileURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).json") }

    private func persist(_ n: Note, immediately: Bool) {
        pendingWrites[n.id]?.cancel()
        if immediately { pendingWrites[n.id] = nil; write(n); return }
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, let latest = self.note(n.id) else { return }
                self.pendingWrites[n.id] = nil
                self.write(latest)
            }
        }
        pendingWrites[n.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func write(_ n: Note) {
        guard let data = try? Self.encoder.encode(n) else { return }
        let url = fileURL(n.id)
        io.async { try? data.write(to: url, options: .atomic) }
    }
}

extension Note {
    var sortDate: Date { startedAt ?? createdAt }
}

enum Paths {
    static let support: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("GranolaIsDead", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    static let recordings: URL = {
        let url = support.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}

/// Audio files for a note: `<noteID>-mic.wav` and `<noteID>-system.wav`.
/// Kept 14 days, then deleted; the transcript is the
/// durable artifact.
enum Recordings {
    /// `<noteID>-<track>[-<n>].wav`; a resumed recording gets the next free n.
    static func nextURL(_ id: UUID, track: String) -> URL {
        var n = 0
        while true {
            let name = n == 0 ? "\(id.uuidString)-\(track).wav" : "\(id.uuidString)-\(track)-\(n).wav"
            let url = Paths.recordings.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { return url }
            n += 1
        }
    }

    static func delete(noteID: UUID) {
        let files = (try? FileManager.default.contentsOfDirectory(at: Paths.recordings, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.lastPathComponent.hasPrefix(noteID.uuidString) { try? FileManager.default.removeItem(at: f) }
    }

    static func cleanupOld(days: Int = 14) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let files = (try? FileManager.default.contentsOfDirectory(at: Paths.recordings, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for f in files where f.pathExtension == "wav" {
            let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            if m < cutoff { try? FileManager.default.removeItem(at: f) }
        }
    }
}
