import Foundation

/// Presentation-only formatting. Storage stays in meters and seconds; the UI
/// converts at the boundary and always keeps the unit visible.
enum AppFormatting {
    static func centimeters(_ meters: Double) -> String {
        guard meters.isFinite else { return "—" }
        return String(format: "%.0f cm", meters * 100)
    }

    static func degrees(_ degrees: Double) -> String {
        guard degrees.isFinite else { return "—" }
        return String(format: "%.1f°", degrees)
    }

    static func seconds(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "—" }
        return String(format: "%.1f s", seconds)
    }

    /// Recording-style clock with tenths, e.g. `00:04.2`.
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00.0" }
        let whole = Int(seconds)
        let tenths = Int((seconds - Double(whole)) * 10)
        return String(format: "%02d:%02d.%d", whole / 60, whole % 60, tenths)
    }

    static func sampleCount(_ count: Int) -> String {
        "\(count) samples"
    }

    static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "—" }
        return String(format: "%.0f%%", min(1, max(0, fraction)) * 100)
    }
}
