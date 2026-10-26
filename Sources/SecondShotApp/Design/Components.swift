import SwiftUI
import SecondShotCore

// MARK: - Buttons

struct SSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.semibold))
            .foregroundStyle(SSColor.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SSSpace.m)
            .background(SSColor.guide.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.medium))
            .foregroundStyle(SSColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SSSpace.m)
            .background(SSColor.surfaceRaised.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SSColor.separator, lineWidth: 1)
            )
    }
}

struct SSQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SSFont.metadata.weight(.medium))
            .foregroundStyle(SSColor.textSecondary)
            .frame(minHeight: SSSpace.minimumTarget)
            .padding(.horizontal, SSSpace.s)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Containers

struct SSCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(SSSpace.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SSSpace.cardCorner, style: .continuous)
                    .fill(SSColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SSSpace.cardCorner, style: .continuous)
                    .stroke(SSColor.separator.opacity(0.7), lineWidth: 1)
            )
    }
}

struct SSEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(SSFont.eyebrow)
            .tracking(1.4)
            .foregroundStyle(SSColor.textSecondary)
    }
}

// MARK: - Badges

struct ModeBadge: View {
    var label: String = "Synthetic demo"
    var symbol: String = "circle.dashed"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(SSFont.badge)
        }
        .foregroundStyle(SSColor.guide)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SSColor.guide.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(SSColor.guide.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// Tracking status with redundant text and shape, never color alone.
struct TrackingBadge: View {
    let availability: TrackingAvailability
    var detail: String?

    private var title: String {
        switch availability {
        case .normal: return "Tracking steady"
        case .limited: return "Tracking limited"
        case .unavailable: return "Guidance unavailable"
        }
    }

    private var symbol: String {
        switch availability {
        case .normal: return "circle.fill"
        case .limited: return "triangle.fill"
        case .unavailable: return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch availability {
        case .normal: return SSColor.guide
        case .limited: return SSColor.caution
        case .unavailable: return SSColor.caution
        }
    }

    var body: some View {
        HStack(spacing: SSSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(SSFont.badge)
                if let detail {
                    Text(detail)
                        .font(SSFont.telemetrySmall)
                        .foregroundStyle(SSColor.textSecondary)
                }
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SSColor.surface.opacity(0.9))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail ?? "")")
    }
}

struct MetricChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(SSFont.eyebrow)
                .foregroundStyle(SSColor.textSecondary)
            Text(value)
                .font(SSFont.telemetry)
                .foregroundStyle(SSColor.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct MetricRow: View {
    let items: [(label: String, value: String)]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SSSpace.s))
            : AnyLayout(HStackLayout(alignment: .top, spacing: SSSpace.m))
        layout {
            ForEach(items.indices, id: \.self) { index in
                MetricChip(label: items[index].label, value: items[index].value)
            }
        }
    }
}

// MARK: - Notices

enum NoticeTone {
    case information
    case caution

    var tint: Color {
        switch self {
        case .information: return SSColor.guide
        case .caution: return SSColor.caution
        }
    }

    var symbol: String {
        switch self {
        case .information: return "info.circle"
        case .caution: return "exclamationmark.triangle"
        }
    }
}

struct InlineNotice: View {
    let title: String
    let message: String
    var tone: NoticeTone = .information

    var body: some View {
        HStack(alignment: .top, spacing: SSSpace.s) {
            Image(systemName: tone.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SSFont.bodyEmphasis)
                    .foregroundStyle(SSColor.textPrimary)
                Text(message)
                    .font(SSFont.metadata)
                    .foregroundStyle(SSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SSSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(SSColor.separator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Screen chrome

struct DemoTopBar<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let trailingContent: Trailing

    init(title: String, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.onBack = onBack
        self.trailingContent = trailing()
    }

    var body: some View {
        HStack(spacing: SSSpace.s) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SSColor.textPrimary)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("demo.back")

            Text(title)
                .font(SSFont.metadata.weight(.medium))
                .foregroundStyle(SSColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: SSSpace.xs)

            trailingContent
        }
        .padding(.horizontal, SSSpace.m)
        .frame(minHeight: SSSpace.minimumTarget)
    }
}
