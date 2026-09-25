import SwiftUI

struct WardrobeView: View {
    @Environment(AppStore.self) private var store

    @State private var hop = 0
    @State private var burst = 0
    @State private var speech: String?
    @State private var speechID = 0
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stageCard

                section("Color") {
                    ForEach(BodyColor.allCases) { option in
                        tile(option, selected: store.look.body == option) { $0.body = option }
                    }
                }
                section("Eyes") {
                    ForEach(EyeStyle.allCases) { option in
                        tile(option, selected: store.look.eyes == option) { $0.eyes = option }
                    }
                }
                section("Pattern") {
                    ForEach(Pattern.allCases) { option in
                        tile(option, selected: store.look.pattern == option) { $0.pattern = option }
                    }
                }
                section("Accessory") {
                    ForEach(Accessory.allCases) { option in
                        tile(option, selected: store.look.accessory == option) { $0.accessory = option }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.paper.ignoresSafeArea())
        .onAppear { name = store.look.name }
    }

    // MARK: Preview

    private var stageCard: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                ZStack {
                    Circle()
                        .fill(store.look.body.base.opacity(0.22))
                        .frame(width: 230, height: 230)
                    CreatureView(look: store.look, stage: store.stage, expression: .happy, hopTrigger: hop, size: 210) {
                        Haptics.soft()
                        say(Lines.pokes.randomElement()!)
                    }
                    HeartBurst(trigger: burst).offset(y: -80)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                if let speech {
                    SpeechBubble(text: speech)
                        .id(speechID)
                        .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
                }
            }

            HStack(spacing: 6) {
                TextField("Name", text: $name)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                    .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .onTapGesture { nameFocused = true }
            }
            .frame(maxWidth: .infinity)

            Text("Level \(store.level) · \(store.stage.title)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity)
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            name = store.look.name
            return
        }
        let capped = String(trimmed.prefix(14))
        name = capped
        guard capped != store.look.name else { return }
        store.updateLook { $0.name = capped }
        hop += 1
        say("\(capped)! I love it.")
    }

    // MARK: Options

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
            LazyVGrid(columns: columns, spacing: 14) {
                content()
            }
        }
    }

    private func tile<Option: Unlockable>(_ option: Option, selected: Bool, apply: @escaping (inout CreatureLook) -> Void) -> some View {
        let locked = option.unlockLevel > store.level
        var preview = store.look
        apply(&preview)
        return Button {
            if locked {
                Haptics.nope()
                say("Unlocks at level \(option.unlockLevel). \(Lines.lockedNudge)")
                return
            }
            guard !selected else { return }
            Haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { store.updateLook(apply) }
            hop += 1
            burst += 1
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    CreatureView(look: preview, stage: store.stage, expression: .calm, size: 78, animated: false)
                        .saturation(locked ? 0 : 1)
                        .opacity(locked ? 0.35 : 1)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                Text(locked ? "Level \(option.unlockLevel)" : option.label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(selected ? Tint.leaf.shade : Palette.inkSoft)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyCardStyle(
            wash: selected ? Tint.leaf.color.opacity(0.12) : .clear,
            edge: selected ? Tint.leaf.color : Palette.edge,
            radius: 18))
        .accessibilityLabel(locked ? "\(option.label), locked until level \(option.unlockLevel)" : option.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func say(_ text: String) {
        speechID += 1
        let id = speechID
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { speech = text }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if speechID == id { withAnimation(.easeOut(duration: 0.2)) { speech = nil } }
        }
    }
}
