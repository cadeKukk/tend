import SwiftUI

struct CheckInFlow: View {
    var onComplete: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var step = 0
    @State private var mood: Mood?
    @State private var feelings: [String] = []
    @State private var note = ""
    @State private var hop = 0
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(steps: 3, current: step) { dismiss() }

            companion
                .padding(.top, 8)

            ZStack {
                switch step {
                case 0: moodStep.transition(stepTransition)
                case 1: feelingsStep.transition(stepTransition)
                default: noteStep.transition(stepTransition)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

            footer
        }
        .background(Palette.paper)
        .interactiveDismissDisabled(mood != nil)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }

    private var companion: some View {
        HStack(alignment: .center, spacing: 6) {
            CreatureView(look: store.look, stage: store.stage, expression: mood?.companionExpression ?? .calm, hopTrigger: hop, size: 110)
            SpeechBubble(text: bubbleText)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: bubbleText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var bubbleText: String {
        switch step {
        case 0: mood?.companionReply ?? "How are you, really?"
        case 1: feelings.isEmpty ? "Any words for it? Pick as many as fit." : "Got it. Naming it helps."
        default: "Anything else on your mind? Totally optional."
        }
    }

    // MARK: Steps

    private var moodStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How are you feeling?")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 8) {
                ForEach(Mood.allCases) { option in
                    Button {
                        Haptics.rigid(0.6 + Double(option.rawValue) * 0.08)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { mood = option }
                        if option.rawValue >= 4 { hop += 1 }
                    } label: {
                        VStack(spacing: 8) {
                            MoodFace(mood: option, size: 52)
                                .scaleEffect(mood == option ? 1.18 : 1)
                                .offset(y: mood == option ? -4 : 0)
                            Text(option.label)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(mood == option ? option.shade : Palette.inkSoft)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyCardStyle(
                        wash: mood == option ? option.color.opacity(0.18) : .clear,
                        edge: mood == option ? option.color : Palette.edge,
                        radius: 18))
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var feelingsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("What's in there?")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                FlowLayout(spacing: 10) {
                    ForEach((mood ?? .okay).suggestedFeelings, id: \.self) { word in
                        let on = feelings.contains(word)
                        Button {
                            Haptics.soft()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                if on { feelings.removeAll { $0 == word } } else { feelings.append(word) }
                            }
                        } label: {
                            Text(word)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(on ? .white : Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(ChunkyCardStyle(
                            fill: on ? (mood ?? .okay).shade : Palette.card,
                            edge: on ? (mood ?? .okay).shade.opacity(0.6) : Palette.edge,
                            radius: 14))
                        .scaleEffect(on ? 1.05 : 1)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
    }

    private var noteStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Want to say more?")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                TextField("What happened, what you need, anything…", text: $note, axis: .vertical)
                    .lineLimit(4...8)
                    .font(.body.weight(.medium))
                    .focused($noteFocused)
                    .padding(16)
                    .chunkyCard(radius: 18)
                if let mood, mood.rawValue <= 2 {
                    SupportCard(urgent: mood == .rough, openURL: openURL)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    noteFocused = false
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.card, shade: Palette.edge, foreground: Palette.ink))
                .frame(width: 70)
                .accessibilityLabel("Back")
            }
            Button(step == 2 ? "Done checking in" : "Continue") {
                noteFocused = false
                if step < 2 {
                    Haptics.soft()
                    step += 1
                } else {
                    save()
                }
            }
            .buttonStyle(ChunkyButtonStyle())
            .disabled(mood == nil)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func save() {
        guard let mood else { return }
        store.logMood(MoodEntry(date: .now, mood: mood, feelings: feelings, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        onComplete()
    }
}

/// Shown when someone rates their mood low. Offers real help without alarm.
struct SupportCard: View {
    var urgent: Bool
    var openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").foregroundStyle(Tint.coral.color)
                Text(urgent ? "You don't have to carry this alone" : "Need someone to talk to?")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
            Text("If things feel like too much, or you're thinking about hurting yourself, you can call or text 988 in the US any time, day or night. Elsewhere, contact your local emergency number or a crisis line.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Call 988") { openURL(URL(string: "tel:988")!) }
                    .buttonStyle(ChunkyButtonStyle(color: Tint.coral.color, shade: Tint.coral.shade))
                Button("Text 988") { openURL(URL(string: "sms:988")!) }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.card, shade: Palette.edge, foreground: Tint.coral.shade))
            }
        }
        .padding(16)
        .chunkyCard(radius: 18)
    }
}
