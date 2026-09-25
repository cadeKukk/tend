import SwiftUI

struct GratitudeFlow: View {
    var onComplete: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var items = ["", "", ""]
    @State private var hop = 0
    @FocusState private var focused: Int?

    private let prompts = [
        "Something that made you smile",
        "Someone you're glad exists",
        "A small thing that went okay",
    ]

    private var filled: Int {
        items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(steps: 3, current: max(0, filled - 1)) { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 6) {
                        CreatureView(look: store.look, stage: store.stage, expression: filled == 3 ? .ecstatic : (filled > 0 ? .happy : .calm), hopTrigger: hop, size: 110)
                        SpeechBubble(text: bubble)
                        Spacer(minLength: 0)
                    }

                    Text("Three good things")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.ink)

                    ForEach(0..<3, id: \.self) { i in
                        let done = !items[i].trimmingCharacters(in: .whitespaces).isEmpty
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(.headline, design: .rounded, weight: .black))
                                .foregroundStyle(done ? .white : Palette.inkSoft)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(done ? Tint.marigold.color : Palette.track))
                                .scaleEffect(done ? 1.08 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.45), value: done)
                            TextField(prompts[i], text: $items[i], axis: .vertical)
                                .lineLimit(1...3)
                                .font(.body.weight(.medium))
                                .focused($focused, equals: i)
                                .submitLabel(i < 2 ? .next : .done)
                                .onSubmit { focused = i < 2 ? i + 1 : nil }
                                .padding(.top, 6)
                        }
                        .padding(14)
                        .chunkyCard(radius: 18)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            Button("Keep these") {
                store.logGratitude(items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                onComplete()
            }
            .buttonStyle(ChunkyButtonStyle(color: Tint.marigold.color, shade: Tint.marigold.shade))
            .disabled(filled < 3)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Palette.paper)
        .onChange(of: filled) { old, new in
            if new > old {
                Haptics.soft()
                hop += 1
            }
        }
    }

    private var bubble: String {
        switch filled {
        case 0: "Tell me three good things. Tiny ones count!"
        case 1: "Ooh. One more?"
        case 2: "Last one!"
        default: "My leaf is doing a little dance."
        }
    }
}
