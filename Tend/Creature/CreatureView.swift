import SwiftUI

enum CreatureExpression: Equatable {
    case sleepy, serene, calm, happy, ecstatic, sad
}

private struct HopValues {
    var y: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
}

private struct WiggleValue {
    var angle: Double = 0
}

/// The companion. Drawn entirely from shapes on a 200×200 canvas, then scaled
/// to `size`, so every part can animate and be restyled independently.
struct CreatureView: View {
    var look: CreatureLook
    var stage: Stage
    var expression: CreatureExpression = .calm
    /// Increment to make the companion hop.
    var hopTrigger: Int = 0
    /// Extra scale driven from outside, e.g. by the breathing exercise.
    var breath: CGFloat = 1
    var size: CGFloat = 200
    /// Thumbnails turn this off so dozens of previews don't all blink and sway.
    var animated = true
    var onPoke: (() -> Void)?

    @State private var blink = false
    @State private var idle = false
    @State private var pokes = 0
    @State private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: Bool { animated && !reduceMotion }
    private var ink: Color { look.body.ink }

    var body: some View {
        KeyframeAnimator(initialValue: HopValues(), trigger: hopTrigger) { hop in
            ZStack {
                if stage >= .radiant {
                    Aura(color: look.body.base, live: live)
                }
                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 120 * stage.scale * (1 + hop.y / 130), height: 16)
                    .offset(y: 92)
                figure
                    .keyframeAnimator(initialValue: WiggleValue(), trigger: pokes) { content, w in
                        content.rotationEffect(.degrees(w.angle), anchor: .bottom)
                    } keyframes: { _ in
                        KeyframeTrack(\.angle) {
                            CubicKeyframe(-10, duration: 0.07)
                            CubicKeyframe(9, duration: 0.1)
                            CubicKeyframe(-6, duration: 0.1)
                            CubicKeyframe(3, duration: 0.1)
                            SpringKeyframe(0, duration: 0.3)
                        }
                    }
                    .rotationEffect(.degrees(Double(drag.width / 14)), anchor: .bottom)
                    .scaleEffect(x: hop.sx * squish.width, y: hop.sy * squish.height * breathing, anchor: .bottom)
                    .offset(y: hop.y)
                if stage == .legendary {
                    Orbiters(live: live)
                }
            }
            .frame(width: 200, height: 200)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                LinearKeyframe(0, duration: 0.1)
                CubicKeyframe(-46, duration: 0.25)
                CubicKeyframe(0, duration: 0.22)
                LinearKeyframe(0, duration: 0.4)
            }
            KeyframeTrack(\.sx) {
                CubicKeyframe(1.15, duration: 0.1)
                CubicKeyframe(0.9, duration: 0.25)
                CubicKeyframe(0.96, duration: 0.17)
                CubicKeyframe(1.2, duration: 0.08)
                SpringKeyframe(1, duration: 0.37, spring: .bouncy)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(0.82, duration: 0.1)
                CubicKeyframe(1.12, duration: 0.25)
                CubicKeyframe(1.04, duration: 0.17)
                CubicKeyframe(0.8, duration: 0.08)
                SpringKeyframe(1, duration: 0.37, spring: .bouncy)
            }
        }
        .scaleEffect(size / 200)
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(pokeGesture, including: onPoke == nil ? .none : .all)
        .onAppear {
            guard live else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { idle = true }
        }
        .task(id: live) {
            guard live else { return }
            await blinkLoop()
        }
        .accessibilityElement()
        .accessibilityLabel("\(look.name), your companion. \(stage.title) stage.")
        .accessibilityAddTraits(onPoke == nil ? [] : .isButton)
        .accessibilityAction { if onPoke != nil { poke() } }
    }

    // MARK: Motion

    private var breathing: CGFloat {
        breath * (live ? (idle ? 1.022 : 0.985) : 1)
    }

    /// Pulling down squashes the body, pulling up stretches it. Like jelly.
    private var squish: CGSize {
        let dy = max(-60, min(60, drag.height))
        let dx = min(60, abs(drag.width))
        return CGSize(width: 1 + dy / 300 + dx / 500, height: 1 - dy / 260)
    }

    private var pokeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                withAnimation(.interactiveSpring) { drag = value.translation }
            }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) < 8 { poke() }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.32)) { drag = .zero }
            }
    }

    private func poke() {
        pokes += 1
        onPoke?()
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.2...5.0)))
            withAnimation(.easeIn(duration: 0.07)) { blink = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.09)) { blink = false }
        }
    }

    // MARK: Figure

    private var figure: some View {
        ZStack {
            arm(side: -1)
            arm(side: 1)
            HStack(spacing: 38) {
                foot
                foot
            }
            .offset(y: 84)
            HeadGrowth(stage: stage, live: live)
                .offset(y: -95 - look.accessory.growthLift)
            bodyShape
            face
            AccessoryView(accessory: look.accessory, ink: ink)
        }
        .frame(width: 200, height: 200)
        .scaleEffect(stage.scale, anchor: .bottom)
    }

    private var armAngle: Double {
        switch expression {
        case .sleepy: 12
        case .sad: 6
        case .serene: 20
        case .calm: 32
        case .happy: 44
        case .ecstatic: 148
        }
    }

    private func arm(side: CGFloat) -> some View {
        Ellipse()
            .fill(look.body.base)
            .overlay(Ellipse().fill(LinearGradient(colors: [.clear, look.body.shade.opacity(0.75)], startPoint: .top, endPoint: .bottom)))
            .frame(width: 26, height: 42)
            .rotationEffect(.degrees(Double(side) * -armAngle), anchor: .top)
            .offset(x: side * 70, y: 36)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: expression)
    }

    private var foot: some View {
        Ellipse()
            .fill(look.body.shade)
            .frame(width: 36, height: 20)
    }

    private var bodyShape: some View {
        ZStack {
            BlobShape().fill(look.body.base)
            PatternLayer(pattern: look.pattern, colors: look.body)
                .clipShape(BlobShape())
            BlobShape().fill(LinearGradient(
                stops: [.init(color: .clear, location: 0.5), .init(color: look.body.shade.opacity(0.85), location: 1)],
                startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(.white.opacity(0.42))
                .frame(width: 36, height: 17)
                .rotationEffect(.degrees(-30))
                .offset(x: -44, y: -38)
            Circle()
                .fill(.white.opacity(0.42))
                .frame(width: 8)
                .offset(x: -20, y: -54)
        }
        .frame(width: 160, height: 140)
        .offset(y: 15)
    }

    // MARK: Face

    private var eyeLook: CGSize {
        CGSize(width: max(-4, min(4, drag.width / 14)), height: max(-3, min(3, drag.height / 14)))
    }

    private var face: some View {
        ZStack {
            Group {
                CreatureEye(style: look.eyes, expression: expression, blink: blink, ink: ink)
                    .offset(x: -30)
                CreatureEye(style: look.eyes, expression: expression, blink: blink, ink: ink)
                    .offset(x: 30)
            }
            .offset(x: eyeLook.width, y: 4 + eyeLook.height)

            if expression == .sad {
                Capsule().fill(ink).frame(width: 16, height: 4).rotationEffect(.degrees(-16)).offset(x: -32, y: -20)
                Capsule().fill(ink).frame(width: 16, height: 4).rotationEffect(.degrees(16)).offset(x: 32, y: -20)
            }

            Ellipse().fill(Palette.blush.opacity(rosy ? 0.6 : 0.32)).frame(width: 20, height: 11).offset(x: -50, y: 28)
            Ellipse().fill(Palette.blush.opacity(rosy ? 0.6 : 0.32)).frame(width: 20, height: 11).offset(x: 50, y: 28)

            if look.pattern == .freckles {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(look.body.shade)
                            .frame(width: 4)
                            .offset(x: side * (44 + Double(i) * 6), y: 18 + Double(i % 2) * 5)
                    }
                }
            }

            mouth.offset(y: 34)

            if expression == .sleepy && live {
                Snores(ink: ink).offset(x: 62, y: -58)
            }
        }
    }

    private var rosy: Bool { expression == .happy || expression == .ecstatic }

    @ViewBuilder
    private var mouth: some View {
        switch expression {
        case .ecstatic:
            ZStack {
                OpenMouth().fill(ink)
                Ellipse().fill(Color(hex: 0xFF7A7A)).frame(width: 18, height: 10).offset(y: 7)
            }
            .frame(width: 34, height: 20)
            .clipShape(OpenMouth())
        case .sleepy:
            Ellipse().fill(ink).frame(width: 9, height: 7)
        case .sad:
            SmileShape(curve: -0.8)
                .stroke(ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 22, height: 12)
        case .serene, .calm:
            SmileShape(curve: 0.9)
                .stroke(ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 24, height: 12)
        case .happy:
            SmileShape(curve: 1.1)
                .stroke(ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 32, height: 16)
        }
    }
}

struct CreatureEye: View {
    var style: EyeStyle
    var expression: CreatureExpression
    var blink: Bool
    var ink: Color

    var body: some View {
        switch expression {
        case .ecstatic:
            EyeArc(up: true)
                .stroke(ink, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                .frame(width: 24, height: 11)
        case .sleepy, .serene:
            EyeArc(up: false)
                .stroke(ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 22, height: 8)
        default:
            open.scaleEffect(y: blink ? 0.08 : 1)
        }
    }

    @ViewBuilder
    private var open: some View {
        switch style {
        case .round:
            ZStack {
                Ellipse().fill(ink).frame(width: 22, height: 28)
                Circle().fill(.white).frame(width: 8).offset(x: -4, y: -6)
                Circle().fill(.white).frame(width: 3.5).offset(x: 4, y: 6)
            }
        case .bead:
            ZStack {
                Circle().fill(ink).frame(width: 15)
                Circle().fill(.white).frame(width: 5).offset(x: -3, y: -3)
            }
        case .sparkle:
            ZStack {
                Ellipse().fill(ink).frame(width: 27, height: 32)
                Circle().fill(.white).frame(width: 11).offset(x: -5, y: -7)
                Circle().fill(.white).frame(width: 5).offset(x: 6, y: 6)
                Circle().fill(.white.opacity(0.7)).frame(width: 3).offset(x: -6, y: 8)
            }
        case .star:
            ZStack {
                StarShape().fill(ink).frame(width: 32, height: 32)
                Circle().fill(.white).frame(width: 6).offset(x: -3, y: -3)
            }
        }
    }
}

private struct PatternLayer: View {
    var pattern: Pattern
    var colors: BodyColor

    var body: some View {
        ZStack {
            switch pattern {
            case .belly:
                Ellipse().fill(colors.belly).frame(width: 98, height: 74).offset(y: 44)
            case .spots:
                ForEach(Self.spots.indices, id: \.self) { i in
                    let spot = Self.spots[i]
                    Circle()
                        .fill(colors.shade.opacity(0.45))
                        .frame(width: spot.2)
                        .offset(x: spot.0, y: spot.1)
                }
            case .plain, .freckles:
                Color.clear
            }
        }
        .frame(width: 160, height: 140)
    }

    private static let spots: [(CGFloat, CGFloat, CGFloat)] = [(46, -34, 22), (-58, 6, 15), (60, 26, 13), (-28, -52, 11), (18, 56, 17), (-50, 46, 10)]
}

private struct HeadGrowth: View {
    var stage: Stage
    var live: Bool
    @State private var sway = false

    private var stemHeight: CGFloat {
        switch stage {
        case .seedling: 24
        case .sprout: 30
        case .bud: 36
        default: 40
        }
    }

    var body: some View {
        let top = 45 - stemHeight
        ZStack {
            Capsule()
                .fill(Palette.stem)
                .frame(width: 6, height: stemHeight + 4)
                .offset(y: 45 - stemHeight / 2)
            leaf(angle: -28, x: 14, y: top + 8)
            if stage >= .sprout {
                leaf(angle: 208, x: -14, y: top + 12)
            }
            if stage == .bud {
                ZStack {
                    Circle().fill(Palette.petal).frame(width: 18, height: 18)
                    Circle().fill(.white.opacity(0.45)).frame(width: 5).offset(x: -4, y: -4)
                }
                .offset(y: top - 5)
            }
            if stage >= .bloom {
                Flower(petals: stage == .legendary ? 8 : 5, petal: stage == .legendary ? Palette.gold : Palette.petal)
                    .offset(y: top - 8)
            }
        }
        .frame(width: 90, height: 90)
        .rotationEffect(.degrees(sway ? 7 : -7), anchor: .bottom)
        .onAppear {
            guard live else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { sway = true }
        }
    }

    private func leaf(angle: Double, x: CGFloat, y: CGFloat) -> some View {
        LeafShape()
            .fill(Palette.leaf)
            .overlay(LeafShape().stroke(Palette.stem.opacity(0.35), lineWidth: 1))
            .frame(width: 30, height: 14)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
    }
}

private struct Flower: View {
    var petals: Int
    var petal: Color

    var body: some View {
        ZStack {
            ForEach(0..<petals, id: \.self) { i in
                Ellipse()
                    .fill(petal)
                    .frame(width: 14, height: 19)
                    .offset(y: -10)
                    .rotationEffect(.degrees(Double(i) * 360 / Double(petals)))
            }
            Circle().fill(Palette.gold).frame(width: 13)
            Circle().fill(Color(hex: 0xFFE08A)).frame(width: 5).offset(x: -2, y: -2)
        }
    }
}

private struct Aura: View {
    var color: Color
    var live: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.6), color.opacity(0)], center: .center, startRadius: 30, endRadius: 108))
            .frame(width: 216, height: 216)
            .scaleEffect(pulse ? 1.07 : 0.93)
            .onAppear {
                guard live else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

private struct Orbiters: View {
    var live: Bool

    var body: some View {
        TimelineView(.animation(paused: !live)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let a = t * 1.1 + Double(i) * 2.094
                    let depth = (sin(a) + 1) / 2
                    Image(systemName: "sparkle")
                        .font(.system(size: 12 + 8 * depth, weight: .bold))
                        .foregroundStyle(Palette.gold)
                        .offset(x: CGFloat(cos(a)) * 98, y: CGFloat(sin(a)) * 22 - 6)
                        .opacity(0.55 + 0.45 * depth)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Snores: View {
    var ink: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Text("z")
                        .font(.system(size: 13 + p * 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink.opacity(0.55 * (1 - p)))
                        .offset(x: p * 18, y: -p * 38)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
