import SecondShotCore
import SwiftUI

struct DemoReviewView: View {
    @EnvironmentObject private var store: DemoSessionStore

    var body: some View {
        ZStack {
            SSColor.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                DemoTopBar(title: "Review", onBack: { Task { await store.goBack() } }) {
                    ModeBadge()
                        .accessibilityIdentifier("demo.badge")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: SSSpace.l) {
                        heading
                        modePicker
                        comparison
                        sourceNote
                        metricsCard
                        actions
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
        .sheet(isPresented: $store.isExportSheetPresented) {
            ExportUnavailableSheet()
                .presentationDetents([.medium])
        }
        .onDisappear {
            if store.route.isEmpty { Task { await store.finishDemo() } }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SSEyebrow(text: "Step 03 · Review")
            Text("Compare the pair")
                .font(SSFont.screenTitle)
                .foregroundStyle(SSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Two synthetic takes of the same arc. Originals stay intact; nothing here is a rendered video.")
                .font(SSFont.body)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        Picker("Comparison mode", selection: $store.reviewMode) {
            ForEach(DemoSessionStore.ReviewMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("review.mode")
    }

    @ViewBuilder
    private var comparison: some View {
        switch store.reviewMode {
        case .reference:
            singlePanel(
                title: "Reference (synthetic)",
                accent: SSColor.guide,
                progress: 1,
                showsCurrent: false,
                secondary: nil
            )
        case .retake:
            singlePanel(
                title: "Retake (synthetic)",
                accent: SSColor.caution,
                progress: 1,
                showsCurrent: false,
                secondary: nil
            )
        case .split:
            HStack(alignment: .top, spacing: SSSpace.s) {
                splitColumn(
                    title: "Reference",
                    accent: SSColor.guide,
                    caption: "Recorded arc"
                )
                splitColumn(
                    title: "Retake",
                    accent: SSColor.caution,
                    caption: "Estimated offset"
                )
            }
        case .overlay:
            SSCard {
                VStack(alignment: .leading, spacing: SSSpace.s) {
                    HStack {
                        Text("Overlay")
                            .font(SSFont.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(SSColor.textSecondary)
                        Spacer()
                        Text("REFERENCE · RETAKE")
                            .font(SSFont.eyebrow)
                            .foregroundStyle(SSColor.textSecondary)
                    }
                    ZStack {
                        ArcSchematic(progress: 1, showsCurrent: false, accent: SSColor.guide)
                        ArcSchematic(
                            progress: 1,
                            offset: CGSize(width: 5, height: -3),
                            showsCurrent: true,
                            showsTarget: false,
                            accent: SSColor.caution,
                            lineWidth: 1.5
                        )
                    }
                    .frame(height: 220)
                    .background(SSColor.canvas.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func singlePanel(
        title: String,
        accent: Color,
        progress: Double,
        showsCurrent: Bool,
        secondary: Color?
    ) -> some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                HStack {
                    Text(title)
                        .font(SSFont.eyebrow)
                        .tracking(1.2)
                        .foregroundStyle(SSColor.textSecondary)
                    Spacer()
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                }
                ArcSchematic(
                    progress: progress,
                    showsCurrent: showsCurrent,
                    accent: accent,
                    secondaryAccent: secondary
                )
                .frame(height: 240)
                .background(SSColor.canvas.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func splitColumn(title: String, accent: Color, caption: String) -> some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            ArcSchematic(progress: 1, showsCurrent: false, showsTarget: true, accent: accent)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(SSColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SSColor.separator.opacity(0.7), lineWidth: 1)
                )

            Text(title)
                .font(SSFont.badge)
                .foregroundStyle(SSColor.textPrimary)
            Text(caption)
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var sourceNote: some View {
        HStack(spacing: SSSpace.xs) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 11, weight: .semibold))
            Text("Synthetic fixture · no recorded media")
                .font(SSFont.telemetrySmall)
        }
        .foregroundStyle(SSColor.textSecondary)
        .accessibilityIdentifier("review.source")
    }

    private var metricsCard: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.s) {
                SSEyebrow(text: "Estimated difference")
                MetricRow(items: [
                    ("Position", store.endDeviation.map { AppFormatting.centimeters($0.translationMeters) } ?? "—"),
                    ("Angle", store.endDeviation.map { AppFormatting.degrees($0.rotationDegrees) } ?? "—"),
                    ("Source", "Synthetic")
                ])
                Text("Computed from synthetic end poses with the core comparator. Similar framing is not identical footage, and no image registration has been attempted.")
                    .font(SSFont.telemetrySmall)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: SSSpace.s) {
            Button {
                // Runs the real export path so the session says why it is
                // unavailable instead of a sheet that asserts it.
                Task { await store.openExport() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SSPrimaryButtonStyle())
            .accessibilityIdentifier("review.export.open")
            .accessibilityHint("Explains why export is unavailable in this build.")

            Button {
                Task { await store.finishDemo() }
            } label: {
                Text("Keep originals and finish")
            }
            .buttonStyle(SSSecondaryButtonStyle())
            .accessibilityIdentifier("review.done")
        }
    }
}

struct ExportUnavailableSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SSColor.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: SSSpace.m) {
                HStack {
                    SSEyebrow(text: "Export")
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SSColor.textSecondary)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("export.close")
                }

                Text(DemoStudio.exportUnavailableTitle)
                    .font(SSFont.screenTitle)
                    .foregroundStyle(SSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("export.unavailable")

                Text(DemoStudio.exportUnavailableExplanation)
                    .font(SSFont.body)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                InlineNotice(
                    title: "What still works",
                    message: "The demo reference, guidance and review run entirely on device with deterministic fixtures. Real capture must pass physical-device validation before any export claim.",
                    tone: .information
                )

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .buttonStyle(SSSecondaryButtonStyle())
                .accessibilityIdentifier("export.dismiss")
            }
            .padding(SSSpace.l)
        }
    }
}

#Preview {
    DemoReviewView()
        .environmentObject(DemoSessionStore())
}
