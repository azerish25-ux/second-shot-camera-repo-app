import Foundation
import SecondShotCore

enum ProjectStoreError: Error, Equatable, Sendable {
    case unreadableRecord(attemptID: String)
    case missingRecord(attemptID: String)
}

/// The storage actor: local-first session records under Application Support.
///
/// One file per attempt, written atomically, so an interrupted finalize leaves at
/// worst the incomplete record that launch recovery is supposed to reconcile — a
/// half-written manifest that claims a complete take is not reachable.
///
/// Phase 04 owns the full project package (media layout, publication, recovery).
/// This actor exists because the lifecycle cannot be honest without somewhere real
/// to commit, mark incomplete and delete.
actor ProjectStore: SessionRecording {
    private let root: URL
    private let fileManager: FileManager

    /// - Parameter root: directory that holds one folder per project. Tests pass a
    ///   fresh temporary directory; the app passes Application Support.
    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    /// The default local-first location. No account, no server, no cloud.
    static func applicationSupportRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("SecondShot/Projects", isDirectory: true)
    }

    func upsert(_ record: SessionRecord) throws {
        let url = fileURL(projectID: record.projectID, attemptID: record.attemptID)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(record)
        // Atomic replace: readers never see a partial file.
        try data.write(to: url, options: [.atomic])
    }

    func complete(attemptID: String, projectID: ProjectID, takeID: TakeID) throws {
        var record = try read(projectID: projectID, attemptID: attemptID)
        record.takeID = takeID
        record.completion = .complete
        record.updatedOnSecond = record.createdOnSecond
        try upsert(record)
    }

    func remove(attemptID: String, projectID: ProjectID) throws {
        let url = fileURL(projectID: projectID, attemptID: attemptID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func records(projectID: ProjectID) throws -> [SessionRecord] {
        let directory = attemptsDirectory(projectID: projectID)
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return try names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .map { name in
                let attemptID = String(name.dropLast(".json".count))
                return try read(projectID: projectID, attemptID: attemptID)
            }
    }

    // MARK: Paths

    private func attemptsDirectory(projectID: ProjectID) -> URL {
        root
            .appendingPathComponent(projectID.rawValue, isDirectory: true)
            .appendingPathComponent("attempts", isDirectory: true)
    }

    private func fileURL(projectID: ProjectID, attemptID: String) -> URL {
        attemptsDirectory(projectID: projectID).appendingPathComponent("\(attemptID).json")
    }

    private func read(projectID: ProjectID, attemptID: String) throws -> SessionRecord {
        let url = fileURL(projectID: projectID, attemptID: attemptID)
        guard let data = try? Data(contentsOf: url) else {
            throw ProjectStoreError.missingRecord(attemptID: attemptID)
        }
        guard let record = try? JSONDecoder().decode(SessionRecord.self, from: data) else {
            throw ProjectStoreError.unreadableRecord(attemptID: attemptID)
        }
        return record
    }
}
