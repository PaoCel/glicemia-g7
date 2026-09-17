import SwiftUI

/// The mark from the app icon, drawn rather than shipped as an image so it stays sharp
/// at any size and follows the palette. A rising trace that turns into an arrow.
struct BrandMark: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let line = w * 0.075

            let points = [
                CGPoint(x: 0.06, y: 0.62), CGPoint(x: 0.24, y: 0.70),
                CGPoint(x: 0.38, y: 0.55), CGPoint(x: 0.52, y: 0.60),
                CGPoint(x: 0.66, y: 0.42),
            ].map { CGPoint(x: $0.x * w, y: $0.y * h) }

            var trace = Path()
            trace.move(to: points[0])
            for point in points.dropFirst() { trace.addLine(to: point) }
            context.stroke(
                trace,
                with: .color(GlucoseTheme.primaryText),
                style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            )

            let tip = CGPoint(x: 0.93 * w, y: 0.20 * h)
            var arrow = Path()
            arrow.move(to: points[points.count - 1])
            arrow.addLine(to: tip)
            arrow.move(to: CGPoint(x: tip.x - w * 0.17, y: tip.y))
            arrow.addLine(to: tip)
            arrow.addLine(to: CGPoint(x: tip.x, y: tip.y + h * 0.17))
            context.stroke(
                arrow,
                with: .color(GlucoseTheme.warning),
                style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size * 0.62)
        .accessibilityHidden(true)
    }
}
