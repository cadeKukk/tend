import SwiftUI

/// Mochi-dome body: rounded top, wide soft bottom.
struct BlobShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.92, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.3))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.94),
                   control2: CGPoint(x: r.minX + w * 0.8, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.2, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.94))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.3),
                   control2: CGPoint(x: r.minX + w * 0.08, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.86, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.34))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.88),
                   control2: CGPoint(x: r.minX + w * 0.78, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.22, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.88))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.34),
                   control2: CGPoint(x: r.minX + w * 0.14, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.45))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.45))
        return p
    }
}

/// A single stroke that smiles (positive curve) or frowns (negative).
struct SmileShape: Shape {
    var curve: CGFloat
    var animatableData: CGFloat {
        get { curve }
        set { curve = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.midY + curve * r.height))
        return p
    }
}

/// "D" shaped open mouth that fits inside its rect.
struct OpenMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.midX, y: r.minY + r.height * 2))
        p.closeSubpath()
        return p
    }
}

/// Closed eye: `up` draws a happy ∩, otherwise a peaceful ‿.
struct EyeArc: Shape {
    var up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        }
        return p
    }
}

struct StarShape: Shape {
    var points = 5
    var innerRatio: CGFloat = 0.48

    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        var p = Path()
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : outer * innerRatio
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * radius, y: c.y + CGFloat(sin(angle)) * radius)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct CheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

struct CrownShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.25))
        p.addLine(to: CGPoint(x: r.minX + w * 0.27, y: r.minY + h * 0.58))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.27, y: r.minY + h * 0.58))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.25))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct CrackShape: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0.04, 0.5), (0.2, 0.41), (0.34, 0.53), (0.5, 0.42), (0.64, 0.55), (0.79, 0.43), (0.96, 0.51)]
        var p = Path()
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: r.minX + pt.0 * r.width, y: r.minY + pt.1 * r.height)
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        return p
    }
}

/// Speech bubble with a tail on the bottom-leading edge.
struct BubbleShape: Shape {
    func path(in r: CGRect) -> Path {
        let tail: CGFloat = 9
        let body = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - tail)
        var p = Path(roundedRect: body, cornerRadius: 16, style: .continuous)
        p.move(to: CGPoint(x: body.minX + 18, y: body.maxY - 1))
        p.addLine(to: CGPoint(x: body.minX + 12, y: r.maxY))
        p.addLine(to: CGPoint(x: body.minX + 32, y: body.maxY - 1))
        p.closeSubpath()
        return p
    }
}

/// Alternating wedges for the level-up sunburst.
struct RaysShape: Shape {
    var count = 12
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = max(r.width, r.height)
        var p = Path()
        let step = 2 * Double.pi / Double(count)
        for i in 0..<count {
            let a = Double(i) * step
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * radius, y: c.y + CGFloat(sin(a)) * radius))
            p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + step / 2)) * radius, y: c.y + CGFloat(sin(a + step / 2)) * radius))
            p.closeSubpath()
        }
        return p
    }
}
