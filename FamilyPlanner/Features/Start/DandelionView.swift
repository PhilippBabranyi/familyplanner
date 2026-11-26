import SwiftUI

/// The dandelion seed head, drawn with a Canvas. Geometry matches the design prototype.
struct DandelionView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 92, y: center.y - 92, width: 184, height: 184)),
                with: .color(Theme.surface.opacity(0.6))
            )

            // Outer ring: 36 seeds. Inner ring: 18 smaller seeds, rotated against the outer one.
            for index in 0..<36 {
                let angle = Double(index) * 10
                let radius = 86 + 7 * sin(Double(index) * 2.3)
                drawSeed(context: context, center: center, angle: angle, radius: radius, scale: 1.0)
            }
            for index in 0..<18 {
                let angle = Double(index) * 20 + 5
                let radius = 62 + 5 * cos(Double(index) * 1.7)
                drawSeed(context: context, center: center, angle: angle, radius: radius, scale: 0.75)
            }

            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)),
                with: .color(Color(hex: 0xB9A66E))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                with: .color(Color(hex: 0x8C7A45))
            )
        }
        .accessibilityHidden(true)
    }

    private func point(from center: CGPoint, angle: Double, radius: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
    }

    private func drawSeed(context: GraphicsContext, center: CGPoint, angle: Double, radius: Double, scale: Double) {
        let start = point(from: center, angle: angle, radius: 12)
        let tip = point(from: center, angle: angle, radius: radius)

        var filament = Path()
        filament.move(to: start)
        filament.addLine(to: tip)
        context.stroke(filament, with: .color(Color(hex: 0xA9A28F)), lineWidth: 1)

        // Small feathery tuft at the tip, rotated to point outwards.
        let offsets: [(Double, Double)] = [(0, -9), (-6, -7), (6, -7), (-9, -3), (9, -3)]
        let radians = angle * .pi / 180
        var tuft = Path()
        for (offsetX, offsetY) in offsets {
            let scaledX = offsetX * scale
            let scaledY = offsetY * scale
            let rotatedX = scaledX * cos(radians) - scaledY * sin(radians)
            let rotatedY = scaledX * sin(radians) + scaledY * cos(radians)
            tuft.move(to: tip)
            tuft.addLine(to: CGPoint(x: tip.x + rotatedX, y: tip.y + rotatedY))
        }
        context.stroke(tuft, with: .color(Theme.seed), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }
}

/// A small dandelion for the menu: a seed head on a stem. Drawn in the current foreground colour.
struct DandelionIcon: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let head = CGPoint(x: 12 * scale, y: 9 * scale)
            var rays = Path()
            var dots = Path()
            for index in 0..<10 {
                let radians = Double(index) * 36 * .pi / 180
                let inner = CGPoint(x: head.x + 2.2 * scale * sin(radians), y: head.y - 2.2 * scale * cos(radians))
                let outer = CGPoint(x: head.x + 7 * scale * sin(radians), y: head.y - 7 * scale * cos(radians))
                rays.move(to: inner)
                rays.addLine(to: outer)
                dots.addEllipse(in: CGRect(x: outer.x - 1.1 * scale, y: outer.y - 1.1 * scale,
                                           width: 2.2 * scale, height: 2.2 * scale))
            }
            var stem = Path()
            stem.move(to: CGPoint(x: head.x, y: head.y + 2.5 * scale))
            stem.addCurve(
                to: CGPoint(x: 12.5 * scale, y: 23 * scale),
                control1: CGPoint(x: 11 * scale, y: 14 * scale),
                control2: CGPoint(x: 13.5 * scale, y: 18 * scale)
            )
            context.stroke(rays, with: .foreground, style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
            context.stroke(stem, with: .foreground, style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round))
            context.fill(dots, with: .foreground)
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - 1.6 * scale, y: head.y - 1.6 * scale,
                                       width: 3.2 * scale, height: 3.2 * scale)),
                with: .foreground
            )
        }
        .accessibilityHidden(true)
    }
}
