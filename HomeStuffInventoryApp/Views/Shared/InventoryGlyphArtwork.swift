import SwiftUI

/// Editable vectors use a 24-point construction grid. Identity drawings rebalance
/// silhouettes and interior detail for larger frames rather than scaling a small glyph.
struct InventoryGlyphArtwork: View {
    let glyph: InventoryGlyph
    let identity: Bool
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height) / 24
            let drawing = InventoryGlyphDrawing(glyph: glyph, identity: identity)
            let transform = CGAffineTransform(scaleX: unit, y: unit)
            let stroke = StrokeStyle(lineWidth: (identity ? 1.15 : 1.85) * unit, lineCap: .round, lineJoin: .round)
            ZStack {
                if identity && glyph != .shelf {
                    drawing.silhouette.applying(transform)
                        .fill(LinearGradient(colors: [tint.opacity(0.48), tint.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    drawing.backPlane.applying(transform).fill(tint.opacity(glyph == .drawer ? 0.3 : 0.28))
                    if glyph == .drawer { drawing.backPlane.applying(transform).fill(.black.opacity(0.25)) }
                }
                if glyph != .drawer { drawing.backPlane.applying(transform).stroke(tint, style: stroke) }
                drawing.silhouette.applying(transform).stroke(tint, style: stroke)
                drawing.detail.applying(transform).stroke(tint, style: stroke)
            }
            .frame(width: 24 * unit, height: 24 * unit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct InventoryGlyphDrawing {
    var silhouette = Path()
    var backPlane = Path()
    var detail = Path()

    init(glyph: InventoryGlyph, identity large: Bool) {
        switch glyph {
        case .kitchen:
            rect(2, large ? 12 : 12.5, 20, large ? 10 : 9, radius: large ? 1.8 : 1.4)
            rect(large ? 13 : 13.5, large ? 6 : 7, large ? 7.5 : 7, large ? 6 : 5.5, radius: large ? 1.6 : 1.2, back: true)
            line([(12, 6), (22, 6)])
            line([(16, 3.5), (18, 3.5)])
            line([(17, 3.5), (17, 5.5)])
            line([(11, 13), (11, 21)])
            line([(large ? 8 : 6.8, 16.5), (large ? 8 : 6.8, 17.5)])
            line([(16, 17), (18, 17)])
            line([(4.5, 12.5), (4.5, 8.5), (8.5, 8.5), (8.5, 12.5)])
        case .office:
            rect(large ? 6 : 7, 2.5, large ? 11 : 10, large ? 7.5 : 7, radius: large ? 0.8 : 0.5)
            line([(12, 10), (12, 12)])
            line([(2, 12), (22, 12), (22, 21.5)])
            rect(3, 13, large ? 5.8 : 5, 8.5, radius: large ? 0.8 : 0.4)
            line([(3.5, 17.2), (8, 17.2)])
            var chair = Path()
            chair.move(to: CGPoint(x: 13.5, y: 18))
            chair.addQuadCurve(to: CGPoint(x: 14.5, y: 14), control: CGPoint(x: 13.6, y: 15))
            chair.addQuadCurve(to: CGPoint(x: 20, y: 14), control: CGPoint(x: 17.5, y: large ? 10 : 11))
            chair.addLine(to: CGPoint(x: 20, y: 18))
            chair.addQuadCurve(to: CGPoint(x: 13.5, y: 18), control: CGPoint(x: 18, y: 20.2))
            chair.closeSubpath()
            backPlane.addPath(chair)
            line([(15, 19.5), (14, 22)])
            line([(19, 19.5), (20, 22)])
        case .bedroom:
            backPlane.move(to: CGPoint(x: 3, y: 12))
            backPlane.addLine(to: CGPoint(x: 3, y: 6))
            backPlane.addQuadCurve(to: CGPoint(x: 6, y: 3), control: CGPoint(x: 3, y: 3))
            backPlane.addLine(to: CGPoint(x: 17, y: 3))
            backPlane.addQuadCurve(to: CGPoint(x: 21, y: 6), control: CGPoint(x: 21, y: 3))
            backPlane.addLine(to: CGPoint(x: 21, y: 12))
            if large {
                for x in [6.0, 13.5] {
                    backPlane.move(to: CGPoint(x: x, y: 12))
                    backPlane.addLine(to: CGPoint(x: x, y: 9))
                    backPlane.addQuadCurve(to: CGPoint(x: x + 1.5, y: 7), control: CGPoint(x: x, y: 7))
                    backPlane.addLine(to: CGPoint(x: x + 3, y: 7))
                    backPlane.addQuadCurve(to: CGPoint(x: x + 4.5, y: 9), control: CGPoint(x: x + 4.5, y: 7))
                    backPlane.addLine(to: CGPoint(x: x + 4.5, y: 12))
                }
            } else {
                line([(7, 11), (7, 8), (10, 8)])
                line([(14, 8), (17, 8), (17, 11)])
            }
            rect(2, 12, 20, large ? 8.5 : 8, radius: large ? 3.5 : 3)
            line([(4.5, 21), (4.5, 22)])
            line([(19.5, 21), (19.5, 22)])
        case .cabinet:
            rect(large ? 2.8 : 3, large ? 2.8 : 3, large ? 18.4 : 18, large ? 18.4 : 18, radius: large ? 2.7 : 2.3)
            line([(12, 3), (12, 21)])
            line([(8, 12), (8, 15)])
            line([(16, 12), (16, 15)])
        case .drawer:
            silhouette = drawer(x: large ? 2 : 3, y: large ? 7 : 8, width: large ? 20 : 18, height: large ? 12 : 10, notch: large ? 6.2 : 5.5, depth: large ? 2.6 : 2.25, radius: large ? 2.8 : 2.3)
            if large {
                backPlane.move(to: CGPoint(x: 8.9, y: 7))
                backPlane.addCurve(to: CGPoint(x: 9.9, y: 9.6), control1: CGPoint(x: 9.3, y: 7), control2: CGPoint(x: 8.7, y: 9.6))
                backPlane.addLine(to: CGPoint(x: 14.1, y: 9.6))
                backPlane.addCurve(to: CGPoint(x: 15.1, y: 7), control1: CGPoint(x: 15.3, y: 9.6), control2: CGPoint(x: 14.7, y: 7))
                backPlane.closeSubpath()
            }
        case .box:
            backPlane.move(to: CGPoint(x: 2.5, y: 8.5))
            for point in [CGPoint(x: 5, y: large ? 4 : 5), CGPoint(x: 19, y: large ? 4 : 5), CGPoint(x: 21.5, y: 8.5)] { backPlane.addLine(to: point) }
            silhouette = drawer(x: 2.5, y: 8.5, width: 19, height: 12, notch: large ? 6 : 5.5, depth: large ? 2.7 : 2.25, radius: large ? 2.3 : 2)
        case .shelf:
            rect(4, 2.5, 16, 19, radius: large ? 0.7 : 0.5)
            line([(4.5, 8), (19.5, 8)])
            line([(4.5, 14), (19.5, 14)])
            line([(4, 21.5), (4, 22)])
            line([(20, 21.5), (20, 22)])
            if large { line([(6.5, 3), (6.5, 21)]); line([(17.5, 3), (17.5, 21)]) }
        case .organizer:
            rect(3, 3, 18, 18, radius: large ? 3.2 : 2.7)
            if large {
                for x in [5.5, 13.5] { for y in [5.5, 13.5] { rect(x, y, 5, 5, radius: 1.3, back: true) } }
            } else {
                line([(12, 3.5), (12, 20.5)])
                line([(3.5, 12), (20.5, 12)])
            }
        case .cable:
            for x in [2.0, 16.0] {
                silhouette.move(to: CGPoint(x: x, y: 5))
                for point in [CGPoint(x: x + 1, y: 5), CGPoint(x: x + 1, y: 2.5), CGPoint(x: x + 5, y: 2.5), CGPoint(x: x + 5, y: 5), CGPoint(x: x + 6, y: 5), CGPoint(x: x + 6, y: 10), CGPoint(x: x, y: 10)] { silhouette.addLine(to: point) }
                silhouette.closeSubpath()
            }
            let coilTop = large ? 10.5 : 11.5
            let coilBottom = large ? 21.3 : 20.5
            detail.move(to: CGPoint(x: 5, y: 10))
            detail.addCurve(to: CGPoint(x: 12, y: coilBottom), control1: CGPoint(x: 4.5, y: 18), control2: CGPoint(x: 6, y: 23))
            detail.addCurve(to: CGPoint(x: 12, y: coilTop), control1: CGPoint(x: 20, y: 22), control2: CGPoint(x: 19, y: 11))
            detail.addCurve(to: CGPoint(x: 12, y: coilBottom), control1: CGPoint(x: 5, y: 11), control2: CGPoint(x: 5, y: 21))
            detail.addCurve(to: CGPoint(x: 19, y: 10), control1: CGPoint(x: 19, y: 23), control2: CGPoint(x: 19.5, y: 16))
        case .keys:
            silhouette.addEllipse(in: CGRect(x: large ? 2.8 : 3, y: 7, width: large ? 6.5 : 6, height: large ? 6.5 : 6))
            silhouette.addEllipse(in: CGRect(x: large ? 13.3 : 13, y: large ? 7 : 7.5, width: large ? 6.5 : 6, height: large ? 6.5 : 6))
            line([(6, 13), (large ? 4.5 : 5, 21.5), (7.5, 21.5)])
            line([(5.5, 17.5), (8, 17.5)])
            line([(16.5, 13.5), (20, 21), (22, 21)])
            line([(18.5, 18), (20.5, 17)])
            detail.move(to: CGPoint(x: 7, y: 9.5))
            detail.addCurve(to: CGPoint(x: 16, y: 8.5), control1: CGPoint(x: 0, y: -1), control2: CGPoint(x: 18, y: -1))
        case .battery:
            silhouette.move(to: CGPoint(x: 8, y: 5.5))
            for point in [CGPoint(x: 10, y: 5.5), CGPoint(x: 10, y: 2.5), CGPoint(x: 14, y: 2.5), CGPoint(x: 14, y: 5.5), CGPoint(x: 16, y: 5.5)] { silhouette.addLine(to: point) }
            silhouette.addQuadCurve(to: CGPoint(x: 17.5, y: 7), control: CGPoint(x: 17.5, y: 5.5))
            silhouette.addLine(to: CGPoint(x: 17.5, y: 20))
            silhouette.addQuadCurve(to: CGPoint(x: 16, y: 21.5), control: CGPoint(x: 17.5, y: 21.5))
            silhouette.addLine(to: CGPoint(x: 8, y: 21.5))
            silhouette.addQuadCurve(to: CGPoint(x: 6.5, y: 20), control: CGPoint(x: 6.5, y: 21.5))
            silhouette.addLine(to: CGPoint(x: 6.5, y: 7))
            silhouette.addQuadCurve(to: CGPoint(x: 8, y: 5.5), control: CGPoint(x: 6.5, y: 5.5))
            silhouette.closeSubpath()
            line([(12, large ? 11 : 12), (12, large ? 16 : 15)])
            line([(large ? 9.5 : 10.5, 13.5), (large ? 14.5 : 13.5, 13.5)])
        case .tools:
            silhouette.move(to: CGPoint(x: large ? 2.5 : 3, y: large ? 3.2 : 3))
            for point in [CGPoint(x: 5, y: large ? 1.8 : 2), CGPoint(x: large ? 8.5 : 8, y: large ? 5.3 : 5), CGPoint(x: large ? 8.1 : 8, y: large ? 7.2 : 7), CGPoint(x: 20.5, y: 18.5)] { silhouette.addLine(to: point) }
            silhouette.addQuadCurve(to: CGPoint(x: 18, y: 21), control: CGPoint(x: 22.5, y: 22))
            for point in [CGPoint(x: 6, y: 8), CGPoint(x: 4, y: 8), CGPoint(x: 2, y: 5)] { silhouette.addLine(to: point) }
            silhouette.closeSubpath()
            backPlane.move(to: CGPoint(x: large ? 22 : 21.5, y: large ? 2.5 : 3))
            backPlane.addQuadCurve(to: CGPoint(x: 15, y: 8), control: CGPoint(x: 14, y: 0))
            backPlane.addLine(to: CGPoint(x: large ? 3.5 : 3, y: large ? 17.8 : 18))
            backPlane.addQuadCurve(to: CGPoint(x: 6, y: 21), control: CGPoint(x: 1, y: 22.5))
            backPlane.addLine(to: CGPoint(x: 17, y: 10))
            backPlane.addQuadCurve(to: CGPoint(x: 22, y: 5), control: CGPoint(x: 23, y: 11))
            backPlane.addLine(to: CGPoint(x: 19, y: 6))
            backPlane.addLine(to: CGPoint(x: 18, y: 5))
            backPlane.closeSubpath()
        }
    }

    private mutating func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, radius: Double, back: Bool = false) {
        let path = Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius)
        if back { backPlane.addPath(path) } else { silhouette.addPath(path) }
    }

    private mutating func line(_ points: [(Double, Double)]) {
        guard let first = points.first else { return }
        detail.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() { detail.addLine(to: CGPoint(x: point.0, y: point.1)) }
    }

    private func drawer(x: Double, y: Double, width: Double, height: Double, notch: Double, depth: Double, radius: Double) -> Path {
        let left = x + width / 2 - notch / 2
        let right = x + width / 2 + notch / 2
        return Path { path in
            path.move(to: CGPoint(x: x + radius, y: y))
            path.addLine(to: CGPoint(x: left, y: y))
            path.addCurve(to: CGPoint(x: left + 1, y: y + depth), control1: CGPoint(x: left + 0.4, y: y), control2: CGPoint(x: left - 0.2, y: y + depth))
            path.addLine(to: CGPoint(x: right - 1, y: y + depth))
            path.addCurve(to: CGPoint(x: right, y: y), control1: CGPoint(x: right + 0.2, y: y + depth), control2: CGPoint(x: right - 0.4, y: y))
            path.addLine(to: CGPoint(x: x + width - radius, y: y))
            path.addQuadCurve(to: CGPoint(x: x + width, y: y + radius), control: CGPoint(x: x + width, y: y))
            path.addLine(to: CGPoint(x: x + width, y: y + height - radius))
            path.addQuadCurve(to: CGPoint(x: x + width - radius, y: y + height), control: CGPoint(x: x + width, y: y + height))
            path.addLine(to: CGPoint(x: x + radius, y: y + height))
            path.addQuadCurve(to: CGPoint(x: x, y: y + height - radius), control: CGPoint(x: x, y: y + height))
            path.addLine(to: CGPoint(x: x, y: y + radius))
            path.addQuadCurve(to: CGPoint(x: x + radius, y: y), control: CGPoint(x: x, y: y))
            path.closeSubpath()
        }
    }
}
