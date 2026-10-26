import SecondShotCore
import SwiftUI

struct DemoReferenceView: View {
    @EnvironmentObject private var store: DemoSessionStore

    var body: some View {
        ZStack {
            SSColor.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                DemoTopBar(title: "Demo studio", onBack: { store.goBack() }) {
                    ModeBadge()
                        .accessibilityIdentifier("demo.badge")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: SSSpace.l) {
                        heading
                        schematicCard
                        metrics
                        stateSection
                        safetyNote
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
            // The demo owns no media; leaving the stage must not leave a timer or
            // a half-finished synthetic take running.
            if store.route.isEmpty { store.finishDemo() }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SSEyebrow(text: "Step 01 · Reference")
            Text("The move to repeat")
                .font(SSFont.screenTitle)
                .foregroundStyle(SSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("A single slow arc, camera-left to camera-right, while the tabletop subject stays centred.")
                .font(SSFont.body)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var schematicCard: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                HStack {
                    Text("Top-down projection")
                        .font(SSFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(SSColor.textSecondary)
                    Spacer()
                    Text(store.hasReference ? "SAVED" : "PLANNED")
                        .font(SSFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(store.hasReference ? SSColor.guide : SSColor.textSecondary)
                }

                ArcSchematic(progress: store.hasReference ? 1 : 0.06)
                    .frame(height: 220)
                    .background(SSColor.canvas.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Text("Start")
                    Spacer()
                    Text("Subject")
                    Spacer()
                    Text("End")
                }
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
            }
        }
    }

    private var metrics: some View {
        SSCard {
            MetricRow(items: [
                ("Duration", AppFormatting.seconds(DemoStudio.projectedDurationSeconds)),
                ("Samples", "\(DemoStudio.sampleCount)"),
                ("Path", AppFormatting.centimeters(0.87)),
                ("Origin", "demo-01")
            ])
        }
    }

    @ViewBuilder
    private var stateSection: some View {
        if let error = store.lastError {
            InlineNotice(
                title: "The demo could not continue",
                message: error,
                tone: .caution
            )
        }

        if store.hasReference {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                InlineNotice(
                    title: "Reference saved (synthetic)",
                    message: "The fixture uses the same session transitions a real take will use. No video exists, and no permission was requested.",
                    tone: .information
                )
                .accessibilityIdentifier("reference.ready")

                Button {
                    store.startRetake()
                } label: {
                    Label("Start demo retake", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SSPrimaryButtonStyle())
                .accessibilityIdentifier("demo.retake.start")
                .accessibilityHint("Opens guided retake on the synthetic path.")
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                Button {
                    store.simulateReference()
                } label: {
                    Label("Simulate reference", systemImage: "circle.dashed")
                }
                .buttonStyle(SSPrimaryButtonStyle())
                .accessibilityIdentifier("demo.reference.create")
                .accessibilityHint("Creates a labelled synthetic reference. Does not record video.")

                Text("The button replays deterministic pose fixtures through the reference transitions. It never substitutes synthetic tracking for a failed camera session.")
                    .font(SSFont.telemetrySmall)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var safetyNote: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SectionDivider()
            Label {
                Text("Short, slow moves in a clear space. Check your footing and surroundings before any real take.")
                    .font(SSFont.telemetrySmall)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(SSColor.textSecondary)
        }
    }
}

#Preview {
    DemoReferenceView()
        .environmentObject(DemoSessionStore())
}
