import SwiftUI
import UIKit

/// Semantic design tokens. Colors adapt to light and dark appearance with the
/// targets from `docs/design/DESIGN_SYSTEM.md`; no view hard-codes its own palette.
enum SSColor {
    static let canvas = adaptive(dark: 0x111315, light: 0xF7F5EF)
    static let surface = adaptive(dark: 0x1C2025, light: 0xFFFFFF)
    static let surfaceRaised = adaptive(dark: 0x292F35, light: 0xE8EBEB)
    static let textPrimary = adaptive(dark: 0xF5F1E8, light: 0x171A1D)
    static let textSecondary = adaptive(dark: 0xB6BBC1, light: 0x505960)
    static let guide = adaptive(dark: 0x7DE8F2, light: 0x006B78)
    static let caution = adaptive(dark: 0xF2BE63, light: 0x805600)
    static let recording = adaptive(dark: 0xFF6969, light: 0xB42332)
    static let separator = adaptive(dark: 0x343A40, light: 0xD9DDDD)
    static let onAccent = adaptive(dark: 0x0B1013, light: 0xFFFFFF)

    private static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum SSSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let pageMargin: CGFloat = 24
    static let cardCorner: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let minimumTarget: CGFloat = 44
}

enum SSFont {
    static let hero = Font.system(.largeTitle, design: .default).weight(.semibold)
    static let screenTitle = Font.system(.title2, design: .default).weight(.semibold)
    static let cardTitle = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let bodyEmphasis = Font.system(.body, design: .default).weight(.medium)
    static let metadata = Font.system(.subheadline, design: .default)
    static let eyebrow = Font.system(.caption2, design: .monospaced).weight(.semibold)
    static let telemetry = Font.system(.body, design: .monospaced).weight(.medium)
    static let telemetrySmall = Font.system(.caption, design: .monospaced).weight(.medium)
    static let badge = Font.system(.caption, design: .default).weight(.semibold)
}

extension View {
    /// Standard page gutters. The horizontal padding is intentionally generous on
    /// regular widths and stays at 16pt on compact screens through layout margins.
    func ssPagePadding() -> some View {
        padding(.horizontal, SSSpace.l)
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
