import SecondShotCore
import SwiftUI

struct DemoGuidanceView: View {
    @EnvironmentObject private var store: DemoSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SSColor.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                DemoTopBar(title: "Guided retake", onBack: { store.goBack() }) {
                    TrackingBadge(
                        availability: store.isTrackingLost ? .unavailable : .normal,
                        detail: store.isTrackingLost ? "Demo paused" : "Synthetic"
                    )
                    .accessibilityIdentifier("retake.tracking.status")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: SSSpace.l) {
                        instructionBlock
                        pathCard
                        progressSection
                        metrics
                        actions
                        footnotes
                    }
                    .ssPagePadding()
                    .padding(.top, SSSpace.s)
                    .padding(.bottom, SSSpace.xxl)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            if store.route.isEmpty { store.finishDemo() }
        }
    }

    private var instruction: String {
        if store.isTrackingLost { return "Guidance unavailable" }
        if store.canStartRetake { return "Reference ready" }
        return store.guidanceReading?.instruction ?? "Preparing guidance"
    }

    private var detail: String {
        if store.isTrackingLost {
            return "Tracking was lost, so this attempt ended and was kept as incomplete. Nothing auto-resumes: review the option below or start a fresh attempt."
        }
        if store.canStartRetake {
            return "The reference arc is saved. Start a retake when you are standing where the original shot began."
        }
        guard let reading = store.guidanceReading else {
            return "Waiting for a valid pose."
        }
        if reading.withinTolerance {
            return "Within tolerance for this moment. Keep the move slow."
        }
        return "Small correction. Check your footing before moving."
    }

    private var instructionBlock: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SSEyebrow(text: eyebrow)

            Text(instruction)
                .font(.system(.title, design: .default).weight(.semibold))
                .foregroundStyle(store.isTrackingLost ? SSColor.caution : SSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("retake.guidance")
                .accessibilityAddTraits(.isHeader)

            Text(detail)
                .font(SSFont.metadata)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: instruction)
    }

    private var pathCard: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                HStack {
                    Text("Path guidance")
                        .font(SSFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(SSColor.textSecondary)
                    Spacer()
                    Text(store.isTrackingLost ? "MARKERS HIDDEN" : "ESTIMATE")
                        .font(SSFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(store.isTrackingLost ? SSColor.caution : SSColor.textSecondary)
                }

                ArcSchematic(
                    progress: store.progress,
                    offset: markerOffset,
                    showsCurrent: true,
                    showsTarget: !store.isTrackingLost,
                    isStale: store.isTrackingLost
                )
                .frame(height: 210)
                .background(SSColor.canvas.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: store.progress)

                HStack {
                    Text("Recorded path")
                    Spacer()
                    Text(store.isTrackingLost ? "No live cue" : "You")
                }
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
            }
        }
    }

    private var markerOffset: CGSize {
        guard let reading = store.guidanceReading, !reading.withinTolerance else { return .zero }
        switch reading.cue {
        case .shiftLeft: return CGSize(width: -16, height: 0)
        case .shiftRight: return CGSize(width: 16, height: 0)
        case .raiseCamera: return CGSize(width: 0, height: -12)
        case .lowerCamera: return CGSize(width: 0, height: 12)
        case .advanceSlowly: return CGSize(width: 0, height: 9)
        case .easeBack: return CGSize(width: 0, height: -9)
        case .turnLeft: return CGSize(width: -9, height: 4)
        case .turnRight: return CGSize(width: 9, height: 4)
        case .hold, .returnToStart: return .zero
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            HStack {
                Text("Elapsed capture time")
                    .font(SSFont.metadata)
                    .foregroundStyle(SSColor.textSecondary)
                Spacer()
                Text("\(AppFormatting.clock(store.elapsed)) / \(AppFormatting.clock(DemoStudio.projectedDurationSeconds))")
                    .font(SSFont.telemetrySmall)
                    .foregroundStyle(SSColor.textPrimary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(SSColor.surfaceRaised)
                    Capsule()
                        .fill(store.isTrackingLost ? SSColor.caution : SSColor.guide)
                        .frame(width: max(6, proxy.size.width * store.progress))
                }
            }
            .frame(height: 6)

            Text("Time progress is separate from spatial alignment.")
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Retake progress")
        .accessibilityValue("\(Int((store.progress * 100).rounded())) percent, \(AppFormatting.clock(store.elapsed)) elapsed")
        .accessibilityIdentifier("retake.progress")
    }

    private var metrics: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                MetricRow(items: [
                    ("Elapsed", AppFormatting.clock(store.elapsed)),
                    ("Distance", store.guidanceReading.map { AppFormatting.centimeters($0.translationMeters) } ?? "—"),
                    ("Angle", store.guidanceReading.map { AppFormatting.degrees($0.rotationDegrees) } ?? "—")
                ])
                Text("Estimated differences from the synthetic reference pose. This is not a measurement of camera precision.")
                    .font(SSFont.telemetrySmall)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("retake.metrics.details")
    }

    private var eyebrow: String {
        if store.isTrackingLost { return "Tracking lost" }
        return store.canStartRetake ? "Saved reference" : "Next correction"
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: SSSpace.s) {
            if let error = store.lastError {
                InlineNotice(title: "Session stopped", message: error, tone: .caution)
            }

            if store.isRecordingRetake {
                Button {
                    store.stopAndReview()
                } label: {
                    Label("Stop and review", systemImage: "stop.fill")
                }
                .buttonStyle(SSPrimaryButtonStyle())
                .accessibilityIdentifier("demo.review.open")
                .accessibilityHint("Ends the synthetic retake and opens review.")

                Button {
                    store.interruptTracking()
                } label: {
                    Label("Simulate tracking loss", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(SSSecondaryButtonStyle())
                .accessibilityIdentifier("demo.tracking.interrupt")
                .accessibilityHint("Shows the unavailable state used when tracking fails.")
            } else if store.isTrackingLost {
                Button {
                    store.resumeTracking()
                } label: {
                    Label("Return to the saved reference", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SSPrimaryButtonStyle())
                .accessibilityIdentifier("demo.tracking.resume")

                Button {
                    store.discardAttempt()
                } label: {
                    Text("Discard this attempt")
                }
                .buttonStyle(SSSecondaryButtonStyle())
                .accessibilityIdentifier("demo.attempt.discard")
            } else {
                Button {
                    store.startRetake()
                } label: {
                    Label("Start retake", systemImage: "record.circle")
                }
                .buttonStyle(SSPrimaryButtonStyle())
                .accessibilityIdentifier("demo.retake.restart")
                .accessibilityHint("Begins a new guided retake of the saved reference.")
            }
        }
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SectionDivider()
            Text("Synthetic rehearsal. No camera frames, sensors or files are involved; the pose maths and session transitions are real.")
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DemoGuidanceView()
        .environmentObject(DemoSessionStore())
}
