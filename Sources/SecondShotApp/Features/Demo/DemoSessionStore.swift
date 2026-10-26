import Foundation
import SecondShotCore
import SwiftUI

/// Drives the synthetic demo journey through the pure `SessionReducer`.
///
/// The store never fabricates a camera, an AR session or a saved movie: it only
/// replays a labelled fixture through the same transitions real adapters use.
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
    @Published private(set) var state = SessionState.initial
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var isRunning = false
    @Published private(set) var referenceTrack: PoseTrack?
    @Published private(set) var retakeTrack: PoseTrack?
    @Published private(set) var lastError: String?
    @Published var reviewMode: ReviewMode = .split
    @Published var isExportSheetPresented = false

    private var ticker: Task<Void, Never>?

    // MARK: Derived presentation

    /// A saved reference exists, so guidance and review are meaningful.
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

    // MARK: Intents

    func openDemo() {
        reset()
        route = [.reference]
    }

    /// Walks the real production path — permission, preparation, reference
    /// capture — with synthetic adapter replies. No camera, sensor or permission
    /// API is touched: the adapter answers locally and the screens stay labelled.
    func simulateReference() {
        guard state.phase == .idle || state.phase == .ready || state.phase == .referenceAvailable else { return }
        do {
            if state.phase == .idle {
                apply(try SessionReducer.reduce(state, intent: .beginSetup))
                apply(try SessionReducer.reduce(state, event: .permissionsResolved(granted: true, code: nil)))
                apply(try SessionReducer.reduce(state, event: .capturePrepared))
            }
            apply(try SessionReducer.reduce(state, intent: .beginReference))
            apply(try SessionReducer.reduce(state, intent: .stopReference))
            apply(try SessionReducer.reduce(state, event: .referenceSaved(takeID: DemoStudio.referenceTake, token: try requireToken())))
            referenceTrack = try DemoStudio.referenceTrack()
            retakeTrack = try DemoStudio.retakeTrack()
        } catch {
            fail(error)
        }
    }

    func startRetake() {
        guard state.phase == .referenceAvailable else { return }
        do {
            apply(try SessionReducer.reduce(state, intent: .prepareRetake))
            apply(try SessionReducer.reduce(state, event: .relocalized(token: try requireToken())))
            apply(try SessionReducer.reduce(state, intent: .startRetake))
            elapsed = 0
            if route.last != .guidance { route.append(.guidance) }
            startTicker()
        } catch {
            fail(error)
        }
    }

    /// Ends the retake through the real interruption path. The take is preserved
    /// as incomplete, so it can never be presented as a finished recording.
    func interruptTracking() {
        guard state.phase == .recordingRetake else { return }
        stopTicker()
        do {
            apply(try SessionReducer.reduce(state, event: .trackingChanged(.unavailable)))
        } catch {
            fail(error)
        }
    }

    /// Deliberate recovery. It never resumes the ended take: the user returns to a
    /// saved reference and can start a fresh attempt.
    func resumeTracking() {
        guard state.phase == .interrupted else { return }
        do {
            apply(try SessionReducer.reduce(state, intent: .resume))
            elapsed = 0
        } catch {
            fail(error)
        }
    }

    /// Abandons an interrupted attempt and returns to the saved reference.
    func discardAttempt() {
        guard state.phase == .interrupted else { return }
        stopTicker()
        do {
            apply(try SessionReducer.reduce(state, intent: .cancel))
            elapsed = 0
            if route.last == .guidance { route.removeLast() }
        } catch {
            fail(error)
        }
    }

    func stopAndReview() {
        guard state.phase == .recordingRetake else { return }
        stopTicker()
        do {
            apply(try SessionReducer.reduce(state, intent: .stopRetake))
            apply(try SessionReducer.reduce(state, event: .retakeSaved(takeID: DemoStudio.retakeTake, token: try requireToken())))
            if route.last != .review { route.append(.review) }
        } catch {
            fail(error)
        }
    }

    func goBack() {
        switch route.last {
        case .review:
            stopTicker()
            applyReviewClose()
            route.removeLast()
        case .guidance:
            stopTicker()
            applyCancellation()
            elapsed = 0
            route.removeLast()
        case .reference:
            reset()
        case .none:
            break
        }
    }

    func finishDemo() {
        stopTicker()
        if state.phase == .reviewing {
            applyReviewClose()
        }
        reset()
    }

    func reset() {
        stopTicker()
        state = .initial
        route = []
        elapsed = 0
        reviewMode = .split
        referenceTrack = nil
        retakeTrack = nil
        lastError = nil
    }

    // MARK: Tick

    private func startTicker() {
        stopTicker()
        isRunning = true
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self else { return }
                if Task.isCancelled { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
        isRunning = false
    }

    private func requireToken() throws -> OperationToken {
        guard let token = state.token else {
            // The synthetic adapter has no result to report if the reducer is not
            // waiting for one; this is a defect, not a success.
            throw SessionError.illegalTransition(from: state.phase, intent: "syntheticAdapterResult")
        }
        return token
    }

    private func tick() {
        guard state.phase == .recordingRetake else { return }
        let next = elapsed + 0.1
        if next >= DemoStudio.projectedDurationSeconds {
            elapsed = DemoStudio.projectedDurationSeconds
            stopTicker()
        } else {
            elapsed = next
        }
    }

    // MARK: Reducer plumbing

    private func apply(_ transition: SessionTransition) {
        lastError = nil
        state = transition.state
        // Synthetic adapters have no side effects to execute. Effects are kept by
        // the reducer so the same transitions can drive real capture later.
    }

    private func applyReviewClose() {
        if let transition = try? SessionReducer.reduce(state, intent: .closeReview) {
            apply(transition)
        }
    }

    private func applyCancellation() {
        if let transition = try? SessionReducer.reduce(state, intent: .cancel) {
            apply(transition)
        }
    }

    private func fail(_ error: Error) {
        stopTicker()
        if let sessionError = error as? SessionError {
            lastError = sessionError.description
        } else if let poseError = error as? PoseError {
            lastError = poseError.description
        } else {
            lastError = "The demo could not continue."
        }
    }
}
