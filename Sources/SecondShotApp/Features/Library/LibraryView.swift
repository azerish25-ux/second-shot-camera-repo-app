import SecondShotCore
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: DemoSessionStore
    @State private var isSettingsPresented = false

    var body: some View {
        ZStack {
            SSColor.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: SSSpace.l) {
                    header
                    heroCard
                    actions
                    workflow
                    footer
                }
                .ssPagePadding()
                .padding(.top, SSSpace.m)
                .padding(.bottom, SSSpace.xxl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SSSpace.s) {
            HStack(alignment: .center) {
                SSEyebrow(text: "Second Shot · Studio")
                Spacer(minLength: SSSpace.s)
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(SSColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("library.settings.open")
            }

            Text("Make the same\nmove. Twice.")
                .font(SSFont.hero)
                .foregroundStyle(SSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Record a short camera move, return to its start, and follow spatial guidance to repeat it for a match cut.")
                .font(SSFont.body)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroCard: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.m) {
                HStack {
                    ModeBadge()
                        .accessibilityIdentifier("demo.badge")
                    Spacer(minLength: SSSpace.xs)
                    Text("01")
                        .font(SSFont.telemetrySmall)
                        .foregroundStyle(SSColor.textSecondary)
                }

                ArcSchematic(progress: 0.42)
                    .frame(height: 196)
                    .background(
                        LinearGradient(
                            colors: [SSColor.surfaceRaised.opacity(0.55), SSColor.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SSColor.separator.opacity(0.6), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(DemoStudio.sceneTitle)
                        .font(SSFont.cardTitle)
                        .foregroundStyle(SSColor.textPrimary)
                    Text(DemoStudio.sceneSummary)
                        .font(SSFont.metadata)
                        .foregroundStyle(SSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SectionDivider()

                MetricRow(items: [
                    ("Duration", AppFormatting.seconds(DemoStudio.projectedDurationSeconds)),
                    ("Samples", "\(DemoStudio.sampleCount)"),
                    ("Path", AppFormatting.centimeters(0.87)),
                    ("Source", "Synthetic")
                ])
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: SSSpace.s) {
            Button {
                Task { await store.openDemo() }
            } label: {
                Label("Explore demo", systemImage: "play.fill")
            }
            .buttonStyle(SSPrimaryButtonStyle())
            .accessibilityIdentifier("library.demo.open")
            .accessibilityHint("Opens the labelled synthetic reference, guidance and review journey.")

            HStack(spacing: 6) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 11, weight: .semibold))
                Text("No camera, microphone or AR session is started.")
                    .font(SSFont.telemetrySmall)
            }
            .foregroundStyle(SSColor.textSecondary)
            .padding(.horizontal, SSSpace.xxs)

            Button {
                // Deliberately inert in this foundation build.
            } label: {
                HStack {
                    Label("Real capture", systemImage: "camera")
                    Spacer()
                    Text("Not in this build")
                        .font(SSFont.telemetrySmall)
                }
            }
            .buttonStyle(SSSecondaryButtonStyle())
            .disabled(true)
            .accessibilityIdentifier("library.capture.open")
            .accessibilityHint("Real camera capture is not implemented in this foundation build.")
        }
    }

    private var workflow: some View {
        VStack(alignment: .leading, spacing: SSSpace.m) {
            SSEyebrow(text: "The workflow")

            VStack(alignment: .leading, spacing: SSSpace.m) {
                workflowStep(
                    number: "01",
                    title: "Record the move",
                    detail: "A short, slow move around a static subject. The reference stays untouched."
                )
                workflowStep(
                    number: "02",
                    title: "Return to the start",
                    detail: "The app estimates the saved origin and says plainly when it cannot."
                )
                workflowStep(
                    number: "03",
                    title: "Repeat with guidance",
                    detail: "One correction at a time, in your camera frame — never a promise of robotic precision."
                )
            }
        }
        .padding(.top, SSSpace.xs)
    }

    private func workflowStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: SSSpace.m) {
            Text(number)
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.guide)
                .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SSFont.bodyEmphasis)
                    .foregroundStyle(SSColor.textPrimary)
                Text(detail)
                    .font(SSFont.metadata)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: SSSpace.s) {
            SectionDivider()
            Text("Foundation build. The studio is a deterministic synthetic demonstration; live capture, origin recovery, image registration and video export are not implemented yet.")
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SSSpace.s)
    }
}

#Preview {
    LibraryView()
        .environmentObject(DemoSessionStore())
}
