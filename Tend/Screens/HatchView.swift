import SwiftUI

/// First launch: tap the egg until it cracks open, then name who comes out.
struct HatchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tapsToHatch = 4

    @State private var taps = 0
    @State private var wobble = 0
    @State private var hatched = false
    @State private var shellsFly = false
    @State private var shellGone = false
    @State private var flash = false
    @State private var hop = 0
    @State private var confetti = 0
    @State private var name = ""
    @State private var color = BodyColor.mint
    @State private var showForm = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                Text(hatched ? "Hi! I'm yours." : "Someone's about to meet you.")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .padding(.horizontal, 24)
                Text(hatched ? "Give me a name?" : taps == 0 ? "Tap the egg." : "Keep going…")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 6)
                    .contentTransition(.opacity)

                ZStack {
                    Circle()
                        .fill(color.base.opacity(hatched ? 0.25 : 0.12))
                        .frame(width: 260, height: 260)
                    if hatched {
                        CreatureView(look: CreatureLook(name: name, body: color), stage: .seedling, expression: .ecstatic, hopTrigger: hop, size: 220) {
                            Haptics.soft()
                            hop += 1
                        }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                    if !shellGone {
                        shell
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 240, height: 240)
                        .blur(radius: 24)
                        .opacity(flash ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .frame(height: 290)
                .padding(.top, 20)

                Spacer(minLength: 20)

                if showForm {
                    form
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hatched)

            ConfettiView(trigger: confetti).ignoresSafeArea()
        }
        .task { await idleWobble() }
    }

    // MARK: Egg

    private var shell: some View {
        ZStack {
            EggView(cracks: taps, tint: color)
                .mask(Rectangle().frame(height: 100).frame(maxHeight: .infinity, alignment: .top))
                .rotationEffect(.degrees(shellsFly ? -50 : 0))
                .offset(x: shellsFly ? -130 : 0, y: shellsFly ? -160 : 0)
            EggView(cracks: taps, tint: color)
                .mask(Rectangle().frame(height: 100).frame(maxHeight: .infinity, alignment: .bottom))
                .rotationEffect(.degrees(shellsFly ? 40 : 0))
                .offset(x: shellsFly ? 120 : 0, y: shellsFly ? 180 : 0)
        }
        .frame(width: 156, height: 196)
        .opacity(shellsFly ? 0 : 1)
        .keyframeAnimator(initialValue: 0.0, trigger: wobble) { content, angle in
            content.rotationEffect(.degrees(angle), anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-8 - Double(taps) * 3, duration: 0.08)
                CubicKeyframe(7 + Double(taps) * 3, duration: 0.12)
                CubicKeyframe(-4, duration: 0.1)
                SpringKeyframe(0, duration: 0.3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { tapEgg() }
        .accessibilityElement()
        .accessibilityLabel("Egg")
        .accessibilityHint("Tap to help it hatch")
        .accessibilityAddTraits(.isButton)
    }

    private func tapEgg() {
        guard !hatched else { return }
        taps += 1
        wobble += 1
        Haptics.rigid(min(1, 0.4 + Double(taps) * 0.18))
        if taps >= Self.tapsToHatch { Task { await hatch() } }
    }

    private func idleWobble() async {
        while !hatched && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.4))
            if !hatched && !reduceMotion { wobble += 1 }
        }
    }

    private func hatch() async {
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeIn(duration: 0.18)) { flash = true }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { hatched = true }
        withAnimation(.easeOut(duration: 0.7)) {
            flash = false
            shellsFly = true
        }
        Haptics.success()
        confetti += 1
        try? await Task.sleep(for: .milliseconds(400))
        hop += 1
        try? await Task.sleep(for: .milliseconds(300))
        shellGone = true
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showForm = true }
    }

    // MARK: Naming

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Pip", text: $name)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .focused($nameFocused)
                .submitLabel(.done)
                .padding(.vertical, 14)
                .chunkyCard(radius: 18)
                .onChange(of: name) { _, new in
                    if new.count > 14 { name = String(new.prefix(14)) }
                }

            HStack(spacing: 12) {
                ForEach(BodyColor.allCases.filter { $0.unlockLevel == 1 }) { option in
                    Button {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { color = option }
                        hop += 1
                    } label: {
                        Circle()
                            .fill(option.base)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(.white, lineWidth: color == option ? 4 : 0))
                            .overlay(Circle().strokeBorder(option.shade, lineWidth: 2))
                            .scaleEffect(color == option ? 1.12 : 1)
                    }
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(color == option ? .isSelected : [])
                }
                Spacer()
                Text("More colors as you grow")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.trailing)
            }

            Text("Every small thing you do for your mind helps \(name.isEmpty ? "Pip" : name) grow.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)

            Button("Let's go") {
                nameFocused = false
                Haptics.success()
                store.hatch(name: name, body: color)
            }
            .buttonStyle(ChunkyButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

struct EggView: View {
    var cracks: Int
    var tint: BodyColor

    var body: some View {
        ZStack {
            EggShape().fill(Color(hex: 0xFFF1D8))
            ZStack {
                Circle().fill(tint.base.opacity(0.7)).frame(width: 34).offset(x: 30, y: -48)
                Circle().fill(Tint.marigold.color.opacity(0.45)).frame(width: 22).offset(x: 36, y: -8)
                Circle().fill(tint.base.opacity(0.6)).frame(width: 28).offset(x: -18, y: 50)
                Circle().fill(Tint.coral.color.opacity(0.35)).frame(width: 16).offset(x: 30, y: 58)
            }
            .frame(width: 156, height: 196)
            .clipShape(EggShape())
            EggShape().fill(LinearGradient(
                stops: [.init(color: .clear, location: 0.5), .init(color: Color(hex: 0xE8C9A0).opacity(0.8), location: 1)],
                startPoint: .top, endPoint: .bottom))
            Ellipse().fill(.white.opacity(0.7)).frame(width: 26, height: 40).rotationEffect(.degrees(20)).offset(x: -36, y: -30)
            CrackShape()
                .trim(from: 0, to: min(1, CGFloat(cracks) / 3))
                .stroke(Color(hex: 0x6B5440), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cracks)
        }
        .frame(width: 156, height: 196)
    }
}
