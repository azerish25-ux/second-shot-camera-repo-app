import SwiftUI

/// A schematic top-down projection of the demo camera move.
///
/// This is deliberately an instrument drawing, not a simulated photograph: the
/// demo has no camera footage and must never look like it does.
struct ArcSchematic: View {
    var progress: Double = 0.35
    var offset: CGSize = .zero
    var showsCurrent = true
    var showsTarget = true
    var accent: Color = SSColor.guide
    var secondaryAccent: Color?
    var isStale = false
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard size.width > 40, size.height > 40 else { return }
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.94)
        let radius = min(size.width * 0.42, size.height * 0.80)
        let startDegrees: Double = 200
        let sweepDegrees: Double = 140
        let clampedProgress = min(1, max(0, progress))

        drawDotGrid(in: &context, size: size)

        // Full planned path, quiet and continuous.
        let planned = arcPath(
            center: center,
            radius: radius,
            start: startDegrees,
            end: startDegrees + sweepDegrees
        )
        context.stroke(
            planned,
            with: .color(SSColor.textSecondary.opacity(isStale ? 0.18 : 0.32)),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 6])
        )

        // Traversed path.
        let traversed = arcPath(
            center: center,
            radius: radius,
            start: startDegrees,
            end: startDegrees + sweepDegrees * clampedProgress
        )
        context.stroke(
            traversed,
            with: .color(accent.opacity(isStale ? 0.25 : 0.95)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        if let secondaryAccent {
            let second = arcPath(
                center: center,
                radius: radius * 0.82,
                start: startDegrees,
                end: startDegrees + sweepDegrees * clampedProgress
            )
            context.stroke(
                second,
                with: .color(secondaryAccent.opacity(0.8)),
                style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round)
            )
        }

        let angle = (startDegrees + sweepDegrees * clampedProgress) * .pi / 180
        let targetPoint = CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )

        let currentPoint = CGPoint(
            x: targetPoint.x + offset.width,
            y: targetPoint.y + offset.height
        )

        if showsCurrent && showsTarget {
            var connector = Path()
            connector.move(to: targetPoint)
            connector.addLine(to: currentPoint)
            context.stroke(
                connector,
                with: .color(SSColor.textSecondary.opacity(isStale ? 0.15 : 0.35)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 4])
            )
        }

        if showsTarget && !isStale {
            let ring = Path(
                ellipseIn: CGRect(
                    x: targetPoint.x - 9,
                    y: targetPoint.y - 9,
                    width: 18,
                    height: 18
                )
            )
            context.stroke(ring, with: .color(accent.opacity(0.85)), lineWidth: 1.5)
            let dot = Path(ellipseIn: CGRect(x: targetPoint.x - 2, y: targetPoint.y - 2, width: 4, height: 4))
            context.fill(dot, with: .color(accent))
        }

        if showsCurrent {
            if isStale {
                // Explicit unavailable marker: a hollow caution cross, not a
                // plausible-looking guidance dot.
                let cross = Path { path in
                    path.move(to: CGPoint(x: currentPoint.x - 5, y: currentPoint.y - 5))
                    path.addLine(to: CGPoint(x: currentPoint.x + 5, y: currentPoint.y + 5))
                    path.move(to: CGPoint(x: currentPoint.x + 5, y: currentPoint.y - 5))
                    path.addLine(to: CGPoint(x: currentPoint.x - 5, y: currentPoint.y + 5))
                }
                context.stroke(cross, with: .color(SSColor.caution), lineWidth: 2)
            } else {
                let halo = Path(ellipseIn: CGRect(x: currentPoint.x - 7, y: currentPoint.y - 7, width: 14, height: 14))
                context.fill(halo, with: .color(accent.opacity(0.18)))
                let dot = Path(ellipseIn: CGRect(x: currentPoint.x - 4, y: currentPoint.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(accent))
            }
        }

        // Origin tick and horizon rule keep the projection legible.
        var axis = Path()
        axis.move(to: CGPoint(x: center.x - radius * 0.62, y: center.y))
        axis.addLine(to: CGPoint(x: center.x + radius * 0.62, y: center.y))
        context.stroke(axis, with: .color(SSColor.separator.opacity(0.9)), lineWidth: 1)

        let subject = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
        context.stroke(subject, with: .color(SSColor.textSecondary.opacity(0.7)), lineWidth: 1)
    }

    private func arcPath(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        return path
    }

    private func drawDotGrid(in context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 22
        var dots = Path()
        var y: CGFloat = spacing / 2
        while y < size.height {
            var x: CGFloat = spacing / 2
            while x < size.width {
                dots.addEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
                x += spacing
            }
            y += spacing
        }
        context.fill(dots, with: .color(SSColor.textSecondary.opacity(0.16)))
    }
}
