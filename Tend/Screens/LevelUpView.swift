import SwiftUI

struct LevelUpView: View {
    let level: Int
    var onClose: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @State private var evolved = false
    @State private var flash = false
    @State private var hop = 0
    @State private var confetti = 0
    @State private var spin = false
    @State private var cardIn = false

    private var newStage: Stage { .forLevel(level) }
    private var oldStage: Stage { .forLevel(level - 1) }
    private var isEvolution: Bool { newStage != oldStage }
    private var unlocks: [Unlock] { Unlocks.at(level: level).filter { $0.kind != "Evolution" } }

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.6 : 0)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 16) {
                Text(isEvolution && evolved ? "EVOLVED!" : "LEVEL UP!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.gold)
                    .shadow(color: Palette.goldShade, radius: 0, x: 0, y: 4)
                    .contentTransition(.opacity)

                ZStack {
                    RaysShape(count: 14)
                        .fill(Palette.gold.opacity(0.28))
                        .frame(width: 330, height: 330)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .mask(Circle().fill(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 160)))
                    CreatureView(
                        look: store.look,
                        stage: isEvolution && !evolved ? oldStage : newStage,
                        expression: .ecstatic,
                        hopTrigger: hop,
                        size: 200)
                    Circle()
                        .fill(.white)
                        .frame(width: 260, height: 260)
                        .blur(radius: 20)
                        .scaleEffect(flash ? 1.2 : 0.2)
                        .opacity(flash ? 1 : 0)
                }
                .frame(height: 240)

                VStack(spacing: 14) {
                    Text("Level \(level)")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if isEvolution {
                        (Text("\(store.look.name) is now ") + Text(newStage.title).bold().foregroundColor(Palette.ink) + Text(". \(newStage.blurb)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    if !unlocks.isEmpty {
                        VStack(spacing: 8) {
                            Text("NEW IN THE WARDROBE")
                                .font(.caption.weight(.black))
                                .tracking(1)
                                .foregroundStyle(Palette.inkSoft)
                            FlowLayout(spacing: 8) {
                                ForEach(unlocks) { item in
                                    Label(item.name, systemImage: item.symbol)
                                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                        .foregroundStyle(Tint.plum.shade)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Tint.plum.color.opacity(0.14)))
                                }
                            }
                        }
                    } else if !isEvolution, let next = Unlocks.next(after: level) {
                        Text("Next surprise at level \(next.level).")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Button("Keep going", action: onClose)
                        .buttonStyle(ChunkyButtonStyle())
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .chunkyCard(radius: 26)
                .offset(y: cardIn ? 0 : 60)
                .opacity(cardIn ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .scaleEffect(shown ? 1 : 0.7)
            .opacity(shown ? 1 : 0)

            ConfettiView(trigger: confetti).ignoresSafeArea()
        }
        .task { await play() }
    }

    private func play() async {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown = true }
        if !reduceMotion {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
        }
        Haptics.success()

        if isEvolution {
            // Build-up hops, then a white flash and the new form.
            for i in 0..<3 {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 400 : 520))
                hop += 1
                Haptics.rigid(0.5 + Double(i) * 0.25)
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.25)) { flash = true }
            try? await Task.sleep(for: .milliseconds(260))
            evolved = true
            Haptics.success()
            withAnimation(.easeOut(duration: 0.6)) { flash = false }
        } else {
            try? await Task.sleep(for: .milliseconds(250))
        }
        hop += 1
        if isEvolution { confetti += 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { cardIn = true }
    }
}
