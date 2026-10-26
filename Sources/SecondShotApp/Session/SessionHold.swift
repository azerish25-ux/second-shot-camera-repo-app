import Foundation

/// Deterministic hold points for fault journeys.
///
/// A journey that needs an operation to be *in flight* while something else happens
/// — a cancellation landing after the writer already finalized, a tracking loss
/// arriving while relocalization runs, a report arriving during preparation —
/// closes a stage, drives the operation to it, asserts, then releases it. Nothing
/// waits on the wall clock, so the interleaving is reproducible run to run.
///
/// It is inert in normal operation: with the stage open, `hold` returns at once.
actor SessionHold {
    enum Stage: String, Sendable, CaseIterable {
        case permission
        case prepare
        case startCapture
        case relocalize
        case finalize
        case export
    }

    private var closedStages: Set<Stage> = []
    private var arrivedStages: Set<Stage> = []
    private var arrivalWaiters: [Stage: [CheckedContinuation<Void, Never>]] = [:]
    private var releaseWaiters: [Stage: [CheckedContinuation<Void, Never>]] = [:]

    /// The adapter side: suspends while the stage is closed.
    ///
    /// The release continuation is registered *before* the arrival is announced,
    /// because the journey resumes as soon as it sees the arrival and may release
    /// immediately. Announcing first would let that release be missed and leave the
    /// adapter parked forever.
    func hold(_ stage: Stage) async {
        guard closedStages.contains(stage) else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters[stage, default: []].append(continuation)
            arrivedStages.insert(stage)
            arrivalWaiters.removeValue(forKey: stage)?.forEach { $0.resume() }
        }
    }

    /// The journey side: returns once an adapter is holding that stage. Always
    /// await arrival before releasing.
    func awaitArrival(of stage: Stage) async {
        if arrivedStages.contains(stage) { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters[stage, default: []].append(continuation)
        }
    }

    /// Lets a holding adapter continue.
    func release(_ stage: Stage) {
        closedStages.remove(stage)
        arrivedStages.remove(stage)
        releaseWaiters.removeValue(forKey: stage)?.forEach { $0.resume() }
    }

    /// Closes a stage before the operation that crosses it is started.
    func close(_ stage: Stage) {
        closedStages.insert(stage)
        arrivedStages.remove(stage)
    }

    /// Stages that currently have an adapter suspended on them. Every journey must
    /// end at zero, or something is still parked inside an adapter.
    func holdingCount() -> Int {
        arrivedStages.count
    }
}
