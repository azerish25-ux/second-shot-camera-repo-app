import Foundation
import SecondShotCore
import SwiftUI

/// The demo journey's UI state, driven entirely by `SessionCoordinator`.
///
/// The store no longer calls the reducer itself: every action goes through the
/// coordinator, which executes the reducer's effects on injected adapters and
/// feeds their replies back as events. The adapters are synthetic and labelled on
/// screen — no camera, AR session, sensor or recorded movie exists in this build —
/// but the transitions, operation identity, storage writes and writer lifecycle
/// are the real ones.
@MainActor
final class DemoSessionStore: ObservableObject {
    enum Route: Hashable {
        case reference
        case guidance
        case review
    }

    enum ReviewMode: String, CaseIterable, Identifiable {
        case reference
        case retake
        case split
        case overlay

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reference: return "Reference"
            case .retake: return "Retake"
            case .split: return "Split"
            case .overlay: return "Overlay"
            }
        }
    }

    @Published var route: [Route] = []
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var referenceTrack: PoseTrack?
    @Published private(set) var retakeTrack: PoseTrack?
    @Published private(set) var lastError: String?
    @Published var reviewMode: ReviewMode = .split
    @Published var isExportSheetPresented = false

    let environment: SessionEnvironment

    private var ticker: Task<Void, Never>?
    private let tickInterval: TimeInterval

    /// - Parameters:
    ///   - environment: the injected providers. `nil` builds the app's composition
    ///     here, inside the main actor, rather than in a default argument: default
    ///     arguments are evaluated outside the actor and the composition root is
    ///     main-actor bound.
    ///   - tickInterval: how often the UI update loop runs while a retake records.
    init(environment: SessionEnvironment? = nil, tickInterval: TimeInterval = 0.1) {
        let resolved = environment ?? SessionEnvironment.synthetic(
            profile: SessionFaultProfile.from(ProcessInfo.processInfo.arguments)
        )
        self.environment = resolved
        self.tickInterval = tickInterval
        resolved.coordinator.sessionDidChange = { [weak self] _ in
            self?.sessionStateChanged()
        }
    }

    var state: SessionState { environment.coordinator.state }

    // MARK: Derived presentation

    var hasReference: Bool {
        switch state.phase {
        case .referenceAvailable, .relocalizing, .guiding, .recordingRetake,
             .finalizingRetake, .reviewing, .exporting:
            return true
        case .idle, .requestingPermission, .preparing, .ready, .recordingReference,
             .finalizingReference, .interrupted, .failed:
            return state.referenceTakeID != nil
        }
    }

    /// Tracking is not usable. The retake has already been ended by the reducer;
    /// this flag never means "paused and still recording".
    var isTrackingLost: Bool {
        state.phase == .interrupted && state.interruption == .trackingLost
    }

    /// The retake can be started from the guidance screen.
    var canStartRetake: Bool { state.phase == .referenceAvailable }

    /// A retake is being recorded right now.
    var isRecordingRetake: Bool { state.phase == .recordingRetake }

    var progress: Double {
        guard DemoStudio.projectedDurationSeconds > 0 else { return 0 }
        return min(1, max(0, elapsed / DemoStudio.projectedDurationSeconds))
    }

    var guidanceReading: GuidanceReading? {
        guard state.phase == .recordingRetake else { return nil }
        return try? DemoStudio.rehearsalCues(atElapsed: elapsed)
    }

    var endDeviation: PoseDeviation? {
        guard let referenceTrack, let retakeTrack else { return nil }
        let time = DemoStudio.projectedDurationSeconds
        guard let reference = try? referenceTrack.sample(atElapsed: time),
              let retake = try? retakeTrack.sample(atElapsed: time) else {
            return nil
        }
        return try? PoseComparator.deviation(reference: reference, candidate: retake)
    }

    /// The diagnostic codes the session ended with, exposed for the report.
    var droppedReplyCount: Int { environment.coordinator.droppedReplies.count }

    /// Whether UI updates are still scheduled. Ending a journey must leave no
    /// detached work running, and this is what the tests assert instead of guessing.
    var hasScheduledTicker: Bool { ticker != nil }

    // MARK: Journey

    func openDemo() async {
        await reset()
        route = [.reference]
    }

    /// Walks the real production path — permission, preparation, reference capture
    /// and finalize — through the coordinator. The adapters answer locally; no
    /// camera, sensor or permission API is touched.
    func simulateReference() async {
        let coordinator = environment.coordinator
        switch state.phase {
        case .idle, .ready, .referenceAvailable:
            break
        case .interrupted:
            // Deliberate recovery: ask for access again. Nothing resumes by itself.
            await coordinator.send(.resume)
        case .failed:
            await coordinator.send(.retry)
        default:
            return
        }

        if coordinator.state.phase == .idle {
            await coordinator.send(.beginSetup)
        }
        guard coordinator.state.phase == .ready else {
            sessionStateChanged()
            return
        }

        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)

        if coordinator.state.phase == .referenceAvailable {
            referenceTrack = try? DemoStudio.referenceTrack()
            retakeTrack = try? DemoStudio.retakeTrack()
        }
        sessionStateChanged()
    }

    func startRetake() async {
        let coordinator = environment.coordinator
        guard coordinator.state.phase == .referenceAvailable else { return }
        await coordinator.send(.prepareRetake)
        await coordinator.send(.startRetake)
        guard coordinator.state.phase == .recordingRetake else {
            sessionStateChanged()
            return
        }
        elapsed = 0
        if route.last != .guidance { route.append(.guidance) }
        startTicker()
        sessionStateChanged()
    }

    func stopAndReview() async {
        let coordinator = environment.coordinator
        guard coordinator.state.phase == .recordingRetake else { return }
        let finalElapsed = coordinator.elapsedSeconds
        stopTicker()
        await coordinator.send(.stopRetake)
        elapsed = finalElapsed
        if coordinator.state.phase == .reviewing, route.last != .review {
            route.append(.review)
        }
        sessionStateChanged()
    }

    /// Reports that the adapter lost tracking. The reducer ends the attempt and
    /// keeps it incomplete; this button exists because the synthetic adapter has no
    /// real sensor to lose tracking on its own.
    func interruptTracking() async {
        guard state.phase == .recordingRetake else { return }
        stopTicker()
        await environment.capture.injectTracking(.unavailable)
        await environment.coordinator.reportTracking(.unavailable)
        sessionStateChanged()
    }

    /// Deliberate recovery. It never resumes the ended take: the user returns to a
    /// saved reference and can start a fresh attempt.
    func resumeTracking() async {
        guard state.phase == .interrupted else { return }
        await environment.capture.injectTracking(.normal)
        await environment.coordinator.send(.resume)
        elapsed = 0
        sessionStateChanged()
    }

    /// Abandons an interrupted attempt and returns to the saved reference.
    func discardAttempt() async {
        guard state.phase == .interrupted else { return }
        stopTicker()
        await environment.coordinator.send(.cancel)
        elapsed = 0
        if route.last == .guidance { route.removeLast() }
        sessionStateChanged()
    }

    /// Runs the real export path. This build has no renderer, so the adapter
    /// reports `export-unavailable` and the sheet explains it rather than
    /// pretending a file exists.
    func openExport() async {
        if state.phase == .reviewing {
            await environment.coordinator.send(.beginExport)
        }
        isExportSheetPresented = true
        sessionStateChanged()
    }

    func goBack() async {
        let coordinator = environment.coordinator
        switch route.last {
        case .review:
            stopTicker()
            await coordinator.send(.closeReview)
            route.removeLast()
        case .guidance:
            stopTicker()
            await coordinator.cancelIfPossible()
            elapsed = 0
            route.removeLast()
        case .reference:
            await reset()
        case .none:
            break
        }
        sessionStateChanged()
    }

    func finishDemo() async {
        stopTicker()
        await environment.coordinator.send(.closeReview)
        await reset()
    }

    /// Called when the app returns to the foreground, which is also how a user
    /// returns from Settings after changing camera access.
    func applicationBecameActive() async {
        await environment.coordinator.applicationBecameActive()
        sessionStateChanged()
    }

    func reset() async {
        stopTicker()
        await environment.coordinator.endSession()
        route = []
        elapsed = 0
        reviewMode = .split
        referenceTrack = nil
        retakeTrack = nil
        lastError = nil
        isExportSheetPresented = false
    }

    // MARK: Tick

    /// One UI update: monotonic elapsed time plus one tracking poll. The app calls
    /// this from the ticker; deterministic tests call it directly instead of
    /// waiting on the wall clock.
    func tick() async {
        await environment.coordinator.pollTracking()
        if state.phase.isRecording {
            elapsed = environment.coordinator.elapsedSeconds
        }
        sessionStateChanged()
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.tick()
                if self.state.phase != .recordingRetake { break }
                try? await Task.sleep(nanoseconds: UInt64(self.tickInterval * 1_000_000_000))
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: Mirroring

    private func sessionStateChanged() {
        lastError = failureMessage
    }

    /// A user-facing reason the session stopped, derived from the state the
    /// reducer produced. Adapter codes are content-free by construction.
    private var failureMessage: String? {
        if let interruption = state.interruption {
            switch interruption {
            case .trackingLost:
                // The guidance screen carries the fuller explanation.
                return nil
            case .cameraDenied:
                return "\(interruption.explanation) Allow camera access for Second Shot in Settings, then try again."
            case .appBackgrounded, .deviceLocked, .storageLow, .thermalPressure,
                 .writerFailure, .sceneNotRecognized:
                return interruption.explanation
            }
        }
        if state.phase == .failed {
            // A user-safe action plus a content-free code: never media, room or
            // personal data, and never the raw error.
            let code = state.diagnosticCode ?? "adapter-failure"
            return "The take was not saved (\(code)). Nothing was published and the saved reference is unchanged. Try again to re-prepare the capture."
        }
        return environment.coordinator.lastError
    }
}
