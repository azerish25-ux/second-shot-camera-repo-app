import Foundation
import SecondShotCore

/// Faults that the simulator journeys can inject through launch arguments.
///
/// A physical device fails on its own schedule; the simulator has to be told. This
/// only changes which synthetic adapter reports what — never the transitions.
enum SessionFaultProfile: String, CaseIterable, Sendable {
    case none
    /// Camera access is refused and stays refused.
    case permissionDenied
    /// Camera access is refused once, then granted, which is how returning from
    /// Settings looks to the app.
    case permissionDeniedThenGranted
    case preparationFailure
    case writerCreationFailure
    case writerFinalizeFailure
    /// Tracking is lost a moment into the capture.
    case trackingLoss

    static let launchArgument = "-ss-fault"

    static func from(_ arguments: [String]) -> SessionFaultProfile {
        guard let index = arguments.firstIndex(of: launchArgument),
              arguments.indices.contains(index + 1) else {
            return .none
        }
        return SessionFaultProfile(rawValue: arguments[index + 1]) ?? .none
    }

    var mediaQueueFault: MediaWriteQueue.Fault {
        switch self {
        case .writerCreationFailure: return .writerCreation
        case .writerFinalizeFailure: return .writerFinalize
        case .none, .permissionDenied, .permissionDeniedThenGranted, .preparationFailure, .trackingLoss:
            return .none
        }
    }
}

// MARK: - Permissions

/// Answers each permission separately. The demo asks only for the camera; the
/// other kinds are here so later phases cannot collapse them into one switch.
final class SyntheticPermissionProvider: PermissionProviding, @unchecked Sendable {
    private let hold: SessionHold?
    private let lock = NSLock()
    private var statuses: [PermissionKind: PermissionStatus] = [
        .camera: .granted,
        .microphone: .notDetermined,
        .photoLibrary: .notDetermined,
        .motion: .notDetermined,
        .notifications: .notDetermined
    ]
    /// When set, the first N camera queries report `denied` and later ones report
    /// `granted`: the same question, asked again after a Settings round trip.
    private var denyCameraQueries: Int?
    private var cameraQueries = 0
    private(set) var requestedKinds: [PermissionKind] = []

    init(profile: SessionFaultProfile, hold: SessionHold? = nil) {
        self.hold = hold
        switch profile {
        case .permissionDenied:
            statuses[.camera] = .denied
        case .permissionDeniedThenGranted:
            denyCameraQueries = 1
        case .none, .preparationFailure, .writerCreationFailure, .writerFinalizeFailure, .trackingLoss:
            break
        }
    }

    func status(of kind: PermissionKind) async -> PermissionStatus {
        // The prompt is the slow part on a device; a journey holds it here to
        // observe the session while the answer is still outstanding.
        await hold?.hold(.permission)
        lock.lock()
        defer { lock.unlock() }
        guard kind == .camera else { return statuses[kind] ?? .notDetermined }
        if let denyCameraQueries {
            cameraQueries += 1
            return cameraQueries <= denyCameraQueries ? .denied : .granted
        }
        return statuses[.camera] ?? .notDetermined
    }

    func request(_ kind: PermissionKind) async -> PermissionStatus {
        lock.lock()
        requestedKinds.append(kind)
        lock.unlock()
        return await status(of: kind)
    }

    func grant(_ kind: PermissionKind) {
        lock.lock()
        statuses[kind] = .granted
        denyCameraQueries = nil
        lock.unlock()
    }
}

// MARK: - Capabilities

final class SyntheticCapabilityProvider: CapabilityProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var value: CaptureCapabilities

    init(
        supportsAugmentedReality: Bool = true,
        trackingAvailability: TrackingAvailability = .normal,
        isThermallyConstrained: Bool = false
    ) {
        value = CaptureCapabilities(
            supportsAugmentedReality: supportsAugmentedReality,
            trackingAvailability: trackingAvailability,
            isThermallyConstrained: isThermallyConstrained
        )
    }

    func capabilities() async -> CaptureCapabilities {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(trackingAvailability: TrackingAvailability) {
        lock.lock()
        value.trackingAvailability = trackingAvailability
        lock.unlock()
    }
}

// MARK: - Capture

/// The synthetic capture source: a labelled stand-in for the ARKit/AVFoundation
/// path that phases 05–07 build.
///
/// It owns three things the coordinator must not fake: writing an incomplete
/// record before media exists, creating exactly one writer through the queue, and
/// deleting both on abandonment. It records pose fixtures only — there are no
/// camera frames, no AR session and no sensor input in this build.
actor SyntheticCaptureSource: CaptureProviding {
    /// Device-representative costs in seconds for the operations the app awaits.
    /// These are *estimates*, used so cancellation latency is the sum of modelled
    /// work instead of a constant; they are not measurements of iOS.
    struct ModelledCosts: Sendable {
        var prepare: TimeInterval = 0.040
        var releasePreparation: TimeInterval = 0.015
        var startCapture: TimeInterval = 0.025
        var finalizeWriter: TimeInterval = 0.055
        var discard: TimeInterval = 0.030
        var stopSensors: TimeInterval = 0.005
        var relocalize: TimeInterval = 0.120
    }

    private let clock: SessionClock
    private let media: MediaWriting
    private let storage: SessionRecording
    private let mediaRoot: URL
    private let profile: SessionFaultProfile
    private let costs: ModelledCosts
    private let hold: SessionHold?

    /// One attempt's identity and media, kept until it is published for good or
    /// abandoned. Keeping the finished entry is what lets a late cancellation
    /// still delete the media and record it produced.
    private struct Attempt {
        let request: CaptureRequest
        let takeID: TakeID
    }

    private var preparationFailuresRemaining: Int
    private var isPrepared = false
    private var attempts: [OperationToken: Attempt] = [:]
    private var openToken: OperationToken?
    private var tracking: TrackingAvailability = .normal
    private var publishedTakes: [TakeID] = []
    private var relocalizationFails = false

    init(
        clock: SessionClock,
        storage: SessionRecording,
        media: MediaWriting,
        mediaRoot: URL,
        profile: SessionFaultProfile = .none,
        costs: ModelledCosts = ModelledCosts(),
        hold: SessionHold? = nil
    ) {
        self.clock = clock
        self.storage = storage
        self.media = media
        self.mediaRoot = mediaRoot
        self.profile = profile
        self.costs = costs
        self.hold = hold
        // A preparation failure fails once, so the documented recovery path
        // (retry after the device became available) can actually be exercised.
        preparationFailuresRemaining = profile == .preparationFailure ? 1 : 0
    }

    // MARK: Lifecycle

    func prepare() async throws {
        advance(costs.prepare)
        await hold?.hold(.prepare)
        if preparationFailuresRemaining > 0 {
            preparationFailuresRemaining -= 1
            throw SessionAdapterError.prepare("capture-prepare-unavailable")
        }
        isPrepared = true
    }

    func releasePreparation() async {
        advance(costs.releasePreparation)
        isPrepared = false
    }

    func startCapture(_ request: CaptureRequest) async throws {
        advance(costs.startCapture)
        // The record is written before any media exists, so a crash between here
        // and finalization leaves an incomplete record rather than a phantom take.
        try await writeIncompleteRecord(for: request)

        let takeID = TakeID("\(request.kind.rawValue)-take-\(request.token.generation)")
        do {
            try await media.openWriter(takeID: takeID)
        } catch {
            advance(costs.discard)
            try? await storage.remove(attemptID: request.attemptID, projectID: request.projectID)
            throw SessionAdapterError.writerCreate(Self.diagnosticCode(for: error))
        }
        try writePlaceholderMedia(takeID)

        attempts[request.token] = Attempt(request: request, takeID: takeID)
        openToken = request.token
        // The writer is open and recording from here on.
        await hold?.hold(.startCapture)
        if profile == .trackingLoss {
            tracking = .unavailable
        }
    }

    func finishCapture(token: OperationToken) async throws -> TakeID {
        guard let attempt = attempts[token] else {
            throw SessionAdapterError.writerFinalize("capture-not-open")
        }
        guard openToken == token else {
            throw SessionAdapterError.writerFinalize("capture-token-mismatch")
        }

        advance(costs.finalizeWriter)
        do {
            try await media.finalizeWriter(takeID: attempt.takeID)
        } catch {
            advance(costs.discard)
            await media.discardWriter(takeID: attempt.takeID)
            openToken = nil
            // The incomplete record and the partial media stay, deliberately: that
            // is what launch recovery reconciles. Nothing is published as complete.
            throw SessionAdapterError.writerFinalize(Self.diagnosticCode(for: error))
        }

        try await storage.complete(
            attemptID: attempt.request.attemptID,
            projectID: attempt.request.projectID,
            takeID: attempt.takeID
        )
        publishedTakes.append(attempt.takeID)
        openToken = nil
        // Held *after* the writer finalized and the record committed: this is the
        // exact window in which a cancellation can arrive too late.
        await hold?.hold(.finalize)
        return attempt.takeID
    }

    func abandonCapture(token: OperationToken?) async {
        advance(costs.discard)
        let target = token ?? openToken
        guard let target, let attempt = attempts.removeValue(forKey: target) else {
            return
        }
        await media.discardWriter(takeID: attempt.takeID)
        removeMedia(attempt.takeID)
        try? await storage.remove(attemptID: attempt.request.attemptID, projectID: attempt.request.projectID)
        if openToken == target {
            openToken = nil
        }
    }

    func preserveCapture(token: OperationToken?) async {
        advance(costs.discard)
        let target = token ?? openToken
        guard let target, let attempt = attempts[target] else {
            return
        }
        // Close the writer so nothing stays open, but keep the file and the record:
        // an interrupted attempt is recoverable, unlike a cancelled one.
        await media.discardWriter(takeID: attempt.takeID)
        if openToken == target {
            openToken = nil
        }
    }

    func stopSensors() async {
        advance(costs.stopSensors)
    }

    func currentTracking() async -> TrackingAvailability {
        tracking
    }

    func beginRelocalization(token: OperationToken) async throws {
        _ = token
        advance(costs.relocalize)
        guard isPrepared else {
            throw SessionAdapterError(stage: .relocalize, code: "capture-not-prepared")
        }
        await hold?.hold(.relocalize)
        guard tracking.supportsPreciseGuidance, !relocalizationFails else {
            throw SessionAdapterError(stage: .relocalize, code: "scene-not-recognised")
        }
        // No world map is persisted in this build, so this reports only that the
        // adapter is prepared and tracking is usable. It is not a relocalization
        // measurement; phases 05–07 own that.
    }

    func cancelRelocalization() async {
        advance(costs.stopSensors)
    }

    // MARK: Test and journey controls

    func injectTracking(_ availability: TrackingAvailability) {
        tracking = availability
    }

    func failRelocalization(_ fails: Bool = true) {
        relocalizationFails = fails
    }


    func publishedTakeIDs() -> [TakeID] {
        publishedTakes
    }

    /// Media files still on disk. Every journey must end at zero after an
    /// abandonment and at one per published take otherwise.
    func mediaFileCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: mediaRoot.path))?.count ?? 0
    }

    // MARK: Internals

    /// Models the cost of work this adapter carried out so cancellation latency is
    /// the sum of awaited operations. A real device advances the system clock by
    /// itself; here the synthetic clock is advanced instead.
    private func advance(_ seconds: TimeInterval) {
        clock.modelCost(seconds)
    }

    private func writeIncompleteRecord(for request: CaptureRequest) async throws {
        let record = SessionRecord(
            attemptID: request.attemptID,
            projectID: request.projectID,
            kind: request.kind,
            takeID: nil,
            completion: .incomplete,
            diagnosticCode: nil,
            createdOnSecond: clock.now(),
            updatedOnSecond: clock.now()
        )
        do {
            try await storage.upsert(record)
        } catch {
            throw SessionAdapterError.prepare("record-write-failed")
        }
    }

    private func writePlaceholderMedia(_ takeID: TakeID) throws {
        try FileManager.default.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
        let url = mediaFileURL(takeID)
        let body = "synthetic placeholder — this build records no camera frames"
        try Data(body.utf8).write(to: url, options: [.atomic])
    }

    private func removeMedia(_ takeID: TakeID) {
        try? FileManager.default.removeItem(at: mediaFileURL(takeID))
    }

    private func mediaFileURL(_ takeID: TakeID) -> URL {
        mediaRoot.appendingPathComponent("\(takeID.rawValue).movie")
    }

    private static func diagnosticCode(for error: Error) -> String {
        if let media = error as? MediaWriteError {
            switch media {
            case let .writerCreationFailed(code), let .writerFinalizeFailed(code):
                return code
            case let .writerAlreadyOpen(open, requested):
                return "writer-busy-\(open.rawValue)-\(requested.rawValue)"
            case let .writerNotOpen(requested):
                return "writer-missing-\(requested.rawValue)"
            }
        }
        return "media-failure"
    }
}

// MARK: - Export

/// Export is not implemented in this foundation. The seam reports that honestly
/// instead of producing a file or a share sheet that does not exist.
struct UnavailableTakeExport: TakeExporting {
    var hold: SessionHold?

    func export(takeID: TakeID, projectID: ProjectID) async throws -> ExportOutcome {
        await hold?.hold(.export)
        throw SessionAdapterError(stage: .export, code: "export-unavailable")
    }

    func cancelExport() async {}
}

// MARK: - Composition

/// The injected seam bundle the app builds once at launch and the tests build per
/// journey. Same coordinator, different providers.
@MainActor
struct SessionEnvironment {
    let clock: SessionClock
    let permissions: SyntheticPermissionProvider
    let capabilities: SyntheticCapabilityProvider
    let media: MediaWriteQueue
    let storage: ProjectStore
    let capture: SyntheticCaptureSource
    /// Deterministic hold points. `nil` in the app; journeys inject one.
    let hold: SessionHold?
    let coordinator: SessionCoordinator

    static let projectID = ProjectID("demo-project")

    /// - Parameters:
    ///   - profile: the fault the simulator journey asked for.
    ///   - clock: `SystemSessionClock` in the app; tests inject a synthetic one.
    ///   - root: directory for synthetic state. Tests pass a fresh temporary
    ///     directory so a journey cannot inherit another journey's records.
    static func synthetic(
        profile: SessionFaultProfile = .none,
        clock: SessionClock = SystemSessionClock(),
        root: URL? = nil,
        hold: SessionHold? = nil,
        exporter: TakeExporting? = nil
    ) -> SessionEnvironment {
        let base = root ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("SecondShotSynthetic", isDirectory: true)
        let storage = ProjectStore(root: base.appendingPathComponent("ProjectRecords", isDirectory: true))
        // The writer is the queue's responsibility, so that is where a writer fault
        // is injected: the capture path then has to report it honestly.
        let media = MediaWriteQueue(clock: clock, fault: profile.mediaQueueFault)
        let permissions = SyntheticPermissionProvider(profile: profile, hold: hold)
        let capabilities = SyntheticCapabilityProvider()
        capabilities.set(
            trackingAvailability: profile == .trackingLoss ? .unavailable : .normal
        )
        let capture = SyntheticCaptureSource(
            clock: clock,
            storage: storage,
            media: media,
            mediaRoot: base.appendingPathComponent("SyntheticMedia", isDirectory: true),
            profile: profile,
            hold: hold
        )
        let coordinator = SessionCoordinator(
            projectID: projectID,
            clock: clock,
            permissions: permissions,
            capabilities: capabilities,
            capture: capture,
            storage: storage,
            media: media,
            exporter: exporter ?? UnavailableTakeExport(hold: hold)
        )
        return SessionEnvironment(
            clock: clock,
            permissions: permissions,
            capabilities: capabilities,
            media: media,
            storage: storage,
            capture: capture,
            hold: hold,
            coordinator: coordinator
        )
    }
}
