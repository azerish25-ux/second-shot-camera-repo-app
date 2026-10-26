import Foundation
import SecondShotCore

// The seams between the pure `SessionReducer` in SecondShotCore and the platform.
//
// Everything the coordinator cannot do on its own — reading a clock, asking for a
// permission, knowing whether the device can track, opening a writer, persisting a
// record — arrives through one of these protocols. Simulator and physical-device
// behaviour therefore differ only in which implementations are injected, never in
// the transitions themselves.

// MARK: - Time

/// Monotonic time source. Recording timelines, durations and latency budgets read
/// this and never the wall clock, so a timezone or clock change cannot move a
/// timeline or invent a duration.
protocol SessionClock: Sendable {
    /// Monotonic seconds since an unspecified origin.
    func now() -> TimeInterval
    /// Waits for the interval. Used by the progress ticker only.
    func sleep(seconds: TimeInterval) async
    /// Accounts for work an adapter carried out. The system clock ignores it
    /// because real time already moved; the synthetic clock advances so modelled
    /// adapter costs are visible in a latency measurement.
    func modelCost(_ seconds: TimeInterval)
}

struct SystemSessionClock: SessionClock {
    func now() -> TimeInterval {
        // `systemUptime` does not jump when the wall clock is corrected.
        ProcessInfo.processInfo.systemUptime
    }

    func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    func modelCost(_ seconds: TimeInterval) {
        _ = seconds
    }
}

/// Deterministic clock for fault journeys. `sleep` advances virtual time instead of
/// waiting, so no test assertion depends on wall-clock duration, and modelled
/// adapter costs make cancellation latency reproducible run to run.
final class SyntheticSessionClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var seconds: TimeInterval

    init(start: TimeInterval = 0) {
        seconds = start
    }

    func now() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return seconds
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        seconds += interval
        lock.unlock()
    }

    func sleep(seconds interval: TimeInterval) async {
        advance(by: interval)
    }

    func modelCost(_ seconds: TimeInterval) {
        advance(by: seconds)
    }
}

// MARK: - Permissions

/// Each permission is answered separately: a granted camera must never be reported
/// as a granted microphone, and the UI explains whichever one is missing.
enum PermissionKind: String, CaseIterable, Sendable {
    case camera
    case microphone
    case photoLibrary
    case motion
    case notifications
}

enum PermissionStatus: String, Sendable, CaseIterable {
    case notDetermined
    case granted
    case denied
    case restricted
    /// The device or the current configuration cannot offer it at all.
    case unavailable

    var allowsCapture: Bool { self == .granted }
}

protocol PermissionProviding: Sendable {
    func status(of kind: PermissionKind) async -> PermissionStatus
    /// Prompts when the status is still undecided. A status the user already
    /// refused is returned as-is: the OS will not prompt twice.
    func request(_ kind: PermissionKind) async -> PermissionStatus
}

// MARK: - Capabilities

struct CaptureCapabilities: Equatable, Sendable {
    var supportsAugmentedReality: Bool
    var trackingAvailability: TrackingAvailability
    var availableStorageBytes: Int64?
    var isThermallyConstrained: Bool

    init(
        supportsAugmentedReality: Bool,
        trackingAvailability: TrackingAvailability,
        availableStorageBytes: Int64? = nil,
        isThermallyConstrained: Bool = false
    ) {
        self.supportsAugmentedReality = supportsAugmentedReality
        self.trackingAvailability = trackingAvailability
        self.availableStorageBytes = availableStorageBytes
        self.isThermallyConstrained = isThermallyConstrained
    }

    /// Capability only, never a promise: the session still has to prepare.
    var canPrepareCapture: Bool {
        supportsAugmentedReality && !isThermallyConstrained
    }
}

protocol CapabilityProviding: Sendable {
    func capabilities() async -> CaptureCapabilities
}

// MARK: - Adapter failure

/// A content-free adapter failure: a stable diagnostic code for support, never
/// media, room or personal data.
struct SessionAdapterError: Error, Equatable, Sendable {
    enum Stage: String, Sendable {
        case prepare
        case writerCreate
        case writerFinalize
        case relocalize
        case export
    }

    let stage: Stage
    let code: String

    static func prepare(_ code: String) -> SessionAdapterError {
        SessionAdapterError(stage: .prepare, code: code)
    }

    static func writerCreate(_ code: String) -> SessionAdapterError {
        SessionAdapterError(stage: .writerCreate, code: code)
    }

    static func writerFinalize(_ code: String) -> SessionAdapterError {
        SessionAdapterError(stage: .writerFinalize, code: code)
    }
}

// MARK: - Capture

enum TakeKind: String, Codable, Sendable, CaseIterable {
    case reference
    case retake
}

/// What a capture provider is asked to record. The token is echoed back with the
/// result so a late reply can be recognised as belonging to an earlier attempt.
struct CaptureRequest: Equatable, Sendable {
    let token: OperationToken
    let projectID: ProjectID
    let attemptID: String
    let kind: TakeKind
    let referenceTakeID: TakeID?
}

protocol CaptureProviding: Sendable {
    /// Acquires the capture path (session, format, tracking start). Throws
    /// `SessionAdapterError.prepare` when the device cannot offer it.
    func prepare() async throws
    /// Releases whatever `prepare` acquired. Safe to repeat.
    func releasePreparation() async
    /// Starts a capture and opens its writer. Throws `SessionAdapterError.writerCreate`
    /// when the writer cannot be created.
    func startCapture(_ request: CaptureRequest) async throws
    /// Stops delivery, finalizes the writer, commits the record and returns the
    /// committed take identity. Throws `SessionAdapterError.writerFinalize`.
    func finishCapture(token: OperationToken) async throws -> TakeID
    /// Abandons one attempt without publishing it: closes its writer, deletes its
    /// media and removes its record, even when the writer had already finalized.
    ///
    /// - Parameter token: the attempt to abandon. `nil` means the attempt that is
    ///   currently open, if any; a finalized attempt is never touched by `nil`.
    ///   Naming the attempt is what stops a late reply for an older attempt from
    ///   deleting a newer attempt's work. Safe to repeat, and safe when no capture
    ///   is open.
    func abandonCapture(token: OperationToken?) async
    /// Stops an attempt without publishing it but keeps what it captured: its media
    /// and its incomplete record survive so recovery can reconcile them. Used when
    /// an interruption — not a cancellation — ended the attempt.
    func preserveCapture(token: OperationToken?) async
    /// Stops sensor and frame delivery without touching media.
    func stopSensors() async
    /// A tracking report for the running capture.
    func currentTracking() async -> TrackingAvailability
    /// Verifies that the saved start position is recognisable in the current
    /// scene. Throws `SessionAdapterError.relocalize` when it is not.
    func beginRelocalization(token: OperationToken) async throws
    /// Stops an in-flight relocalization attempt. Safe when none is running.
    func cancelRelocalization() async
}

/// What an export actually produced. The project is reported by the adapter — not
/// assumed by the coordinator — so a reply for another project is detectable.
struct ExportOutcome: Equatable, Sendable {
    let projectID: ProjectID
    let takeID: TakeID
}

/// Exports are not implemented in this foundation; the seam exists so phase 12 can
/// supply a real renderer without changing the reducer or the coordinator.
protocol TakeExporting: Sendable {
    func export(takeID: TakeID, projectID: ProjectID) async throws -> ExportOutcome
    func cancelExport() async
}

// MARK: - Storage

/// One persisted session record. An attempt is written *before* its media is
/// finalized, so a crash mid-finalize leaves an incomplete record that launch
/// recovery can reconcile instead of a phantom complete take.
struct SessionRecord: Codable, Equatable, Sendable {
    enum Completion: String, Codable, Sendable {
        case incomplete
        case complete
    }

    let attemptID: String
    let projectID: ProjectID
    let kind: TakeKind
    /// Present only once the record is complete.
    var takeID: TakeID?
    var completion: Completion
    /// Content-free diagnostic, e.g. `writer-finalize-2`.
    var diagnosticCode: String?
    let createdOnSecond: TimeInterval
    var updatedOnSecond: TimeInterval
}

protocol SessionRecording: Sendable {
    /// Inserts or replaces the record for an attempt.
    func upsert(_ record: SessionRecord) async throws
    /// Marks an attempt complete and attaches the take it produced.
    func complete(attemptID: String, projectID: ProjectID, takeID: TakeID) async throws
    /// Removes an attempt and any record it produced. Safe when it does not exist.
    func remove(attemptID: String, projectID: ProjectID) async throws
    func records(projectID: ProjectID) async throws -> [SessionRecord]
}

// MARK: - Media writers

enum MediaWriteStage: String, Codable, Sendable {
    case writerOpened
    case writerFinalized
    case writerDiscarded
    case writerCreationFailed
    case writerFinalizeFailed
}

/// One entry in the writer lifecycle log. Ordering is the point: a take may only
/// be published after its writer was opened and finalized, and a discarded take
/// must never be finalized afterwards.
struct MediaWriteEntry: Equatable, Sendable {
    let takeID: TakeID
    let stage: MediaWriteStage
    let atSecond: TimeInterval
}

enum MediaWriteError: Error, Equatable, Sendable {
    /// A second writer was requested while one was still open. The queue is
    /// serialized, so this is a defect rather than a state the app should reach.
    case writerAlreadyOpen(open: TakeID, requested: TakeID)
    case writerNotOpen(requested: TakeID)
    case writerCreationFailed(code: String)
    case writerFinalizeFailed(code: String)
}

protocol MediaWriting: Sendable {
    func openWriter(takeID: TakeID) async throws
    func finalizeWriter(takeID: TakeID) async throws
    func discardWriter(takeID: TakeID?) async
    /// Number of writers still open. Every journey must end at zero.
    func openWriterCount() async -> Int
    func entries() async -> [MediaWriteEntry]
}
