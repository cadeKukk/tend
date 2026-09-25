import SwiftUI

struct HabitEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var composing = false

    private var unusedIdeas: [Habit] {
        let titles = Set(store.data.habits.map(\.title))
        return (Habit.ideas + Habit.starters).filter { !titles.contains($0.title) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.data.habits) { habit in
                        HStack(spacing: 12) {
                            IconTile(symbol: habit.symbol, tint: habit.tint, size: 34)
                            Text(habit.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            Text("+\(habit.xp)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Palette.goldShade)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { store.removeHabits(at: $0) }
                    .onMove { store.moveHabits(from: $0, to: $1) }
                } header: {
                    Text("Your daily list")
                } footer: {
                    Text("Swipe to remove. Past progress stays either way.")
                }

                if !unusedIdeas.isEmpty {
                    Section("Ideas") {
                        ForEach(unusedIdeas) { idea in
                            Button {
                                Haptics.soft()
                                withAnimation { store.addHabit(idea.fresh) }
                            } label: {
                                HStack(spacing: 12) {
                                    IconTile(symbol: idea.symbol, tint: idea.tint, size: 34)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(idea.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                                        Text(idea.subtitle).font(.caption.weight(.medium)).foregroundStyle(Palette.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Tint.leaf.color)
                                }
                            }
                            .accessibilityLabel("Add \(idea.title)")
                        }
                    }
                }

                Section {
                    Button {
                        composing = true
                    } label: {
                        Label("Make your own", systemImage: "pencil.line")
                            .font(.body.weight(.bold))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .navigationTitle("Your list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $composing) {
                HabitComposer()
                    .environment(store)
            }
        }
    }
}

struct HabitComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subtitle = ""
    @State private var symbol = "star.fill"
    @State private var tint = Tint.leaf

    private var draft: Habit {
        Habit(title: title.isEmpty ? "Your new habit" : title, subtitle: subtitle.isEmpty ? "Something kind for yourself" : subtitle, symbol: symbol, tint: tint)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TaskRow(habit: draft, done: false) { _ in }
                        .allowsHitTesting(false)

                    VStack(spacing: 10) {
                        TextField("What is it?", text: $title)
                            .font(.headline)
                            .padding(14)
                            .chunkyCard(radius: 16)
                        TextField("A little note (optional)", text: $subtitle)
                            .font(.subheadline)
                            .padding(14)
                            .chunkyCard(radius: 16)
                    }

                    Text("Color").font(.system(.headline, design: .rounded, weight: .heavy))
                    HStack(spacing: 12) {
                        ForEach(Tint.allCases) { option in
                            Button {
                                Haptics.soft()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { tint = option }
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: tint == option ? 4 : 0))
                                    .overlay(Circle().strokeBorder(option.shade, lineWidth: 2))
                                    .scaleEffect(tint == option ? 1.12 : 1)
                            }
                            .accessibilityLabel(option.rawValue)
                            .accessibilityAddTraits(tint == option ? .isSelected : [])
                        }
                    }

                    Text("Icon").font(.system(.headline, design: .rounded, weight: .heavy))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                        ForEach(Habit.symbolChoices, id: \.self) { choice in
                            Button {
                                Haptics.soft()
                                symbol = choice
                            } label: {
                                Image(systemName: choice)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(symbol == choice ? .white : Palette.ink)
                                    .frame(width: 52, height: 52)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(symbol == choice ? tint.color : Palette.card))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(symbol == choice ? tint.shade : Palette.edge, lineWidth: 2))
                            }
                            .accessibilityLabel(choice)
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.paper)
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addHabit(Habit(title: title.trimmingCharacters(in: .whitespaces), subtitle: subtitle.isEmpty ? "Something kind for yourself" : subtitle, symbol: symbol, tint: tint))
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
