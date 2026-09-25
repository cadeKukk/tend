import SwiftUI

// MARK: Hearts and sparkles rising off the companion

private struct BurstParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let rise: CGFloat
    let symbol: String
    let color: Color
    let size: CGFloat
    let delay: Double
}

struct HeartBurst: View {
    var trigger: Int
    @State private var particles: [BurstParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(particles) { RisingParticle(particle: $0) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { spawn() }
    }

    private func spawn() {
        guard !reduceMotion else { return }
        let options: [(String, Color)] = [
            ("heart.fill", Palette.blush), ("heart.fill", Color(hex: 0xFF5E6C)),
            ("sparkle", Palette.gold), ("star.fill", Palette.gold),
        ]
        let batch = (0..<8).map { i in
            let pick = options.randomElement()!
            return BurstParticle(
                x: .random(in: -90...90), rise: .random(in: 70...130),
                symbol: pick.0, color: pick.1, size: .random(in: 14...24),
                delay: Double(i) * 0.04)
        }
        particles += batch
        let ids = Set(batch.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            particles.removeAll { ids.contains($0.id) }
        }
    }
}

private struct RisingParticle: View {
    let particle: BurstParticle
    @State private var launched = false
    @State private var faded = false

    var body: some View {
        Image(systemName: particle.symbol)
            .font(.system(size: particle.size, weight: .bold))
            .foregroundStyle(particle.color)
            .scaleEffect(launched ? 1 : 0.2)
            .offset(x: launched ? particle.x : particle.x * 0.2, y: launched ? -particle.rise : 10)
            .opacity(faded ? 0 : 1)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(particle.delay)) { launched = true }
                withAnimation(.easeIn(duration: 0.45).delay(0.85 + particle.delay)) { faded = true }
            }
    }
}

// MARK: Confetti

private struct ConfettiPiece {
    let x: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let w: CGFloat
    let h: CGFloat
    let spin: Double
    let flip: Double
    let delay: Double
    let color: Color
    let round: Bool
}

struct ConfettiView: View {
    var trigger: Int
    @State private var start: Date?
    @State private var pieces: [ConfettiPiece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: Double = 3.4

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { ctx, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                let fade = max(0, min(1, 1 - (t - (Self.duration - 0.9)) / 0.9))
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0 else { continue }
                    // Launch upward, air drag slows horizontal drift, gravity pulls down.
                    let x = p.x * size.width + p.vx * (1 - exp(-2.2 * tt)) / 2.2
                    let y = size.height * 0.42 + p.vy * tt + 0.5 * 1150 * tt * tt
                    var c = ctx
                    c.opacity = fade
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * tt))
                    c.scaleBy(x: cos(p.flip * tt), y: 1)
                    let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                    let path = p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
                    c.fill(path, with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { launch() }
    }

    private func launch() {
        guard !reduceMotion else { return }
        let colors = Tint.allCases.map(\.color) + [Palette.gold, Palette.blush]
        pieces = (0..<70).map { _ in
            let round = Bool.random() && Bool.random()
            return ConfettiPiece(
                x: .random(in: 0.3...0.7), vx: .random(in: -520...520), vy: .random(in: -1050...(-450)),
                w: round ? 9 : .random(in: 7...11), h: round ? 9 : .random(in: 12...18),
                spin: .random(in: -9...9), flip: .random(in: 4...12), delay: .random(in: 0...0.18),
                color: colors.randomElement()!, round: round)
        }
        let stamp = Date.now
        start = stamp
        Task {
            try? await Task.sleep(for: .seconds(Self.duration))
            if start == stamp {
                start = nil
                pieces = []
            }
        }
    }
}

// MARK: Speech bubble

struct SpeechBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 19)
            .background {
                BubbleShape()
                    .fill(Palette.card)
                    .shadow(color: Palette.edge, radius: 0, x: 0, y: 3)
            }
            .frame(maxWidth: 190, alignment: .leading)
    }
}

// MARK: Orbs that fly from a finished task into the companion

struct Orb: Identifiable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let xp: Int
}

private struct BezierFlight: ViewModifier, Animatable {
    var t: CGFloat
    let from: CGPoint
    let to: CGPoint

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        // Arc up and inward, like it's being tossed.
        let control = CGPoint(x: from.x + (to.x - from.x) * 0.2 - 40, y: min(from.y, to.y) - 90)
        let u = 1 - t
        let x = u * u * from.x + 2 * u * t * control.x + t * t * to.x
        let y = u * u * from.y + 2 * u * t * control.y + t * t * to.y
        return content
            .scaleEffect(1 - 0.45 * t)
            .position(x: x, y: y)
    }
}

struct OrbView: View {
    let orb: Orb
    var onLand: () -> Void
    @State private var t: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().fill(orb.color.opacity(0.35)).frame(width: 34, height: 34).blur(radius: 6)
            Circle().fill(orb.color).frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 3))
            Image(systemName: "sparkle").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
        }
        .modifier(BezierFlight(t: t, from: orb.from, to: orb.to))
        .onAppear {
            withAnimation(.easeIn(duration: 0.55)) { t = 1 } completion: { onLand() }
        }
    }
}

/// "+15 XP" that pops up off the checkbox and drifts away.
struct XPFloater: View {
    let orb: Orb
    @State private var popped = false
    @State private var faded = false

    var body: some View {
        Text("+\(orb.xp) XP")
            .font(.system(.subheadline, design: .rounded, weight: .black))
            .foregroundStyle(Palette.goldShade)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Palette.card))
            .scaleEffect(popped ? 1 : 0.4)
            .opacity(faded ? 0 : 1)
            .position(x: orb.from.x - 44, y: orb.from.y - (popped ? 30 : 0) - (faded ? 24 : 0))
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { popped = true }
                withAnimation(.easeIn(duration: 0.45).delay(0.6)) { faded = true }
            }
    }
}
