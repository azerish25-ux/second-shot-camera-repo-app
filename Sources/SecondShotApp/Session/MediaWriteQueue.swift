import Foundation
import SecondShotCore

/// The serialized media writer queue.
///
/// At most one writer is open at a time, because the capture path can only hold
/// one movie being written. Every open, finalize and discard is appended to an
/// ordered log, so a journey can be checked afterwards for the things that are
/// hard to see in a running app: a writer that was never closed, a take published
/// before its writer finalized, or a discarded take that finalized anyway.
actor MediaWriteQueue: MediaWriting {
    /// Injected fault used by the simulator fault journeys. A real device fails on
    /// its own; the synthetic profile has to be told when to.
    enum Fault: Equatable, Sendable {
        case none
        case writerCreation
        case writerFinalize
    }

    private let clock: SessionClock
    private var open: [TakeID] = []
    private var log: [MediaWriteEntry] = []
    private var fault: Fault

    init(clock: SessionClock, fault: Fault = .none) {
        self.clock = clock
        self.fault = fault
    }

    func openWriter(takeID: TakeID) throws {
        if let existing = open.first {
            // Never silently replace a live writer: that is how a take loses its
            // media without anybody noticing.
            throw MediaWriteError.writerAlreadyOpen(open: existing, requested: takeID)
        }
        if fault == .writerCreation {
            record(takeID, .writerCreationFailed)
            throw MediaWriteError.writerCreationFailed(code: "writer-create-\(log.count)")
        }
        open.append(takeID)
        record(takeID, .writerOpened)
    }

    func finalizeWriter(takeID: TakeID) throws {
        guard let index = open.firstIndex(of: takeID) else {
            throw MediaWriteError.writerNotOpen(requested: takeID)
        }
        if fault == .writerFinalize {
            record(takeID, .writerFinalizeFailed)
            throw MediaWriteError.writerFinalizeFailed(code: "writer-finalize-\(log.count)")
        }
        open.remove(at: index)
        record(takeID, .writerFinalized)
    }

    /// Discards the given writer, or every open writer when `takeID` is nil.
    /// Repeated and unnecessary discards are recorded once and are not an error:
    /// cleanup must be idempotent because it runs on several failure paths.
    func discardWriter(takeID: TakeID?) {
        if let takeID {
            guard let index = open.firstIndex(of: takeID) else { return }
            open.remove(at: index)
            record(takeID, .writerDiscarded)
            return
        }
        let abandoned = open
        open.removeAll()
        for entry in abandoned {
            record(entry, .writerDiscarded)
        }
    }

    func openWriterCount() -> Int {
        open.count
    }

    func entries() -> [MediaWriteEntry] {
        log
    }

    private func record(_ takeID: TakeID, _ stage: MediaWriteStage) {
        log.append(MediaWriteEntry(takeID: takeID, stage: stage, atSecond: clock.now()))
    }
}
