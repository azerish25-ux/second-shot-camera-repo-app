import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: SSSpace.l) {
                        introduction
                        facts
                        privacy
                    }
                    .ssPagePadding()
                    .padding(.vertical, SSSpace.l)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .accessibilityIdentifier("settings.sheet")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SSEyebrow(text: "Second Shot")
            Text("A synthetic studio, built honestly.")
                .font(SSFont.screenTitle)
                .foregroundStyle(SSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("This build proves the foundation: domain maths, session transitions, tests and the studio interface. It does not record video.")
                .font(SSFont.body)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var facts: some View {
        SSCard {
            VStack(alignment: .leading, spacing: SSSpace.m) {
                factRow(label: "Version", value: "0.1.0 (foundation)")
                SectionDivider()
                factRow(label: "Camera", value: "Not requested")
                SectionDivider()
                factRow(label: "Microphone", value: "Not requested")
                SectionDivider()
                factRow(label: "AR tracking", value: "Not in this build")
                SectionDivider()
                factRow(label: "Export", value: "Not implemented")
            }
        }
    }

    private func factRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(SSFont.metadata)
                .foregroundStyle(SSColor.textSecondary)
            Spacer(minLength: SSSpace.s)
            Text(value)
                .font(SSFont.telemetrySmall)
                .foregroundStyle(SSColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: SSSpace.xs) {
            SSEyebrow(text: "Privacy")
            Text("No account, no analytics, no network requests and no advertising SDK. The demo uses deterministic fixtures that live in the app bundle.")
                .font(SSFont.metadata)
                .foregroundStyle(SSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SettingsView()
}
