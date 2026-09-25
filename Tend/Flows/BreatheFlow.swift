import SwiftUI

/// One minute of 4-second-in, 6-second-out breathing. The companion inflates with you.
struct BreatheFlow: View {
    var onComplete: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case ready, inhale, exhale, done }
    private static let cycles = 6
    private static let inhale: Double = 4
    private static let exhale: Double = 6

    @State private var phase = Phase.ready
    @State private var cycle = 0
    @State private var fill: CGFloat = 0
    @State private var hop = 0
    @State private var runner: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                SheetHeader { dismiss() }
                Spacer()

                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: phase)
                Text(subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 4)
                    .multilineTextAlignment(.center)

                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Tint.sky.color.opacity(0.12 - Double(i) * 0.03))
                            .frame(width: 180 + CGFloat(i) * 50, height: 180 + CGFloat(i) * 50)
                            .scaleEffect(0.75 + fill * 0.35)
                    }
                    Circle()
                        .strokeBorder(Tint.sky.color.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [2, 9]))
                        .frame(width: 286, height: 286)
                    CreatureView(look: store.look, stage: store.stage, expression: expression, hopTrigger: hop, breath: 1 + fill * 0.2, size: 190)
                }
                .frame(height: 320)
                .padding(.top, 20)

                HStack(spacing: 8) {
                    ForEach(0..<Self.cycles, id: \.self) { i in
                        Capsule()
                            .fill(i < cycle || phase == .done ? Tint.sky.color : Palette.track)
                            .frame(width: i == cycle && phase != .done && phase != .ready ? 26 : 12, height: 12)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cycle)
                .padding(.top, 12)
                .accessibilityLabel("Breath \(min(cycle + 1, Self.cycles)) of \(Self.cycles)")

                Spacer()

                button
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(Palette.paper)
        .onDisappear { runner?.cancel() }
    }

    private var expression: CreatureExpression {
        switch phase {
        case .ready: .calm
        case .inhale, .exhale: .serene
        case .done: .ecstatic
        }
    }

    private var title: String {
        switch phase {
        case .ready: "Breathe with me"
        case .inhale: "Breathe in…"
        case .exhale: "…and out"
        case .done: "Lovely."
        }
    }

    private var subtitle: String {
        switch phase {
        case .ready: "Six slow breaths. About a minute."
        case .inhale: "through your nose"
        case .exhale: "slow, like a sigh"
        case .done: "A whole minute of calm. That's yours now."
        }
    }

    @ViewBuilder
    private var button: some View {
        switch phase {
        case .ready:
            Button("Start") { start() }
                .buttonStyle(ChunkyButtonStyle(color: Tint.sky.color, shade: Tint.sky.shade))
        case .inhale, .exhale:
            Button("Stop") {
                runner?.cancel()
                withAnimation(.easeInOut(duration: 0.6)) {
                    phase = .ready
                    fill = 0
                    cycle = 0
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.card, shade: Palette.edge, foreground: Palette.inkSoft))
        case .done:
            Button("Collect") { onComplete() }
                .buttonStyle(ChunkyButtonStyle())
        }
    }

    private func start() {
        runner = Task {
            for c in 0..<Self.cycles {
                cycle = c
                phase = .inhale
                Haptics.soft()
                withAnimation(.easeInOut(duration: Self.inhale)) { fill = 1 }
                try? await Task.sleep(for: .seconds(Self.inhale))
                if Task.isCancelled { return }
                phase = .exhale
                Haptics.soft()
                withAnimation(.easeInOut(duration: Self.exhale)) { fill = 0 }
                try? await Task.sleep(for: .seconds(Self.exhale))
                if Task.isCancelled { return }
            }
            cycle = Self.cycles
            phase = .done
            hop += 1
            Haptics.success()
        }
    }
}
