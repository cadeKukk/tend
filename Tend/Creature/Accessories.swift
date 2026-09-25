import SwiftUI

extension Accessory {
    /// Hats push the head sprout up so it pokes out of the top instead of hiding underneath.
    var growthLift: CGFloat {
        switch self {
        case .beanie: 17
        case .crown: 22
        default: 0
        }
    }
}

/// Accessories in creature-canvas coordinates (origin at the canvas center).
struct AccessoryView: View {
    var accessory: Accessory
    var ink: Color

    var body: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .bow:
            Bow().rotationEffect(.degrees(18)).offset(x: 48, y: -44)
        case .beanie:
            Beanie().offset(y: -45)
        case .glasses:
            Glasses(ink: ink).offset(y: 4)
        case .headphones:
            Headphones()
        case .crown:
            Crown().offset(y: -66)
        }
    }
}

private struct Bow: View {
    var body: some View {
        let red = Color(hex: 0xFF5E6C)
        ZStack {
            Ellipse().fill(red).frame(width: 26, height: 18).rotationEffect(.degrees(-25)).offset(x: -12)
            Ellipse().fill(red).frame(width: 26, height: 18).rotationEffect(.degrees(25)).offset(x: 12)
            Ellipse().fill(.white.opacity(0.35)).frame(width: 8, height: 5).offset(x: -15, y: -3)
            Circle().fill(Color(hex: 0xD93F50)).frame(width: 11)
        }
    }
}

private struct Beanie: View {
    var body: some View {
        let knit = Color(hex: 0xFF8A3D)
        let band = Color(hex: 0xE0662A)
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: 56, topTrailingRadius: 56, style: .continuous)
                .fill(knit)
                .frame(width: 114, height: 46)
                .overlay {
                    HStack(spacing: 14) {
                        ForEach(0..<6, id: \.self) { _ in
                            Capsule().fill(band.opacity(0.35)).frame(width: 3, height: 26)
                        }
                    }
                    .offset(y: 4)
                }
                .offset(y: -8)
            Capsule()
                .fill(band)
                .frame(width: 124, height: 17)
        }
        .frame(width: 124, height: 54)
    }
}

private struct Glasses: View {
    var ink: Color

    var body: some View {
        ZStack {
            ForEach([-30.0, 30.0], id: \.self) { x in
                Circle()
                    .fill(.white.opacity(0.18))
                    .overlay(Circle().stroke(ink, lineWidth: 4.5))
                    .frame(width: 40, height: 40)
                    .offset(x: x)
            }
            Capsule().fill(ink).frame(width: 14, height: 4.5).offset(y: -4)
        }
    }
}

private struct Headphones: View {
    var body: some View {
        let band = Color(hex: 0x3D3A4A)
        let cup = Color(hex: 0x3FA9F5)
        ZStack {
            Circle()
                .trim(from: 0.55, to: 0.95)
                .stroke(band, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 172, height: 172)
                .offset(y: 12)
            ForEach([-1.0, 1.0], id: \.self) { side in
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(cup)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.3)).padding(6))
                    .frame(width: 24, height: 44)
                    .offset(x: side * 82, y: 14)
            }
        }
    }
}

private struct Crown: View {
    var body: some View {
        ZStack {
            CrownShape()
                .fill(LinearGradient(colors: [Palette.gold, Palette.goldShade], startPoint: .top, endPoint: .bottom))
                .frame(width: 66, height: 36)
            Circle().fill(Color(hex: 0xFF5E6C)).frame(width: 9).offset(y: 8)
            Circle().fill(Color(hex: 0x3FA9F5)).frame(width: 7).offset(x: -20, y: 10)
            Circle().fill(Color(hex: 0x3CC47C)).frame(width: 7).offset(x: 20, y: 10)
        }
    }
}
