import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hop = 0
    @State private var burst = 0
    @State private var banner: Banner?
    @State private var cheering = false
    @State private var speech: String?
    @State private var speechID = 0
    @State private var orbs: [Orb] = []
    @State private var creatureFrame = FrameBox()
    @State private var sheetHabit: Habit?
    @State private var pendingOrigin: CGPoint = .zero
    @State private var showEditor = false

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                habitat
                ScrollView {
                    list
                }
                .scrollIndicators(.hidden)
            }

            effects
        }
        .overlay(alignment: .top) {
            if let banner {
                BannerView(banner: banner)
                    .id(banner.id)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $sheetHabit) { habit in
            flow(for: habit)
                .presentationCornerRadius(32)
                .presentationBackground(Palette.paper)
                .environment(store)
        }
        .sheet(isPresented: $showEditor) {
            HabitEditor()
                .presentationCornerRadius(32)
                .environment(store)
        }
        .task {
            #if DEBUG
            // `-autotap <index>` completes a habit on launch so the reward animation can be screenshotted.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-autotap"), i + 1 < args.count, let index = Int(args[i + 1]),
               store.data.habits.indices.contains(index) {
                try? await Task.sleep(for: .seconds(1.5))
                reward(store.data.habits[index], from: CGPoint(x: 350, y: 720))
                return
            }
            #endif
            try? await Task.sleep(for: .milliseconds(600))
            say(Lines.greeting(done: store.doneToday, total: store.data.habits.count, name: store.look.name))
        }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()).uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(Palette.inkSoft)
                Text(greeting)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            StatPill(symbol: "flame.fill", color: Palette.flame, text: "\(store.currentStreak)", bounce: store.currentStreak)
                .accessibilityLabel("\(store.currentStreak) day streak")
            Button {
                showEditor = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.card))
                    .overlay(Circle().strokeBorder(Palette.edge, lineWidth: 2))
            }
            .accessibilityLabel("Edit your list")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: Companion habitat

    private var expression: CreatureExpression {
        if cheering { return .ecstatic }
        let done = store.doneToday
        let total = store.data.habits.count
        if done == 0 { return .sleepy }
        if total > 0, Double(done) / Double(total) >= 0.5 { return .happy }
        return .calm
    }

    private var habitat: some View {
        let look = store.look
        return VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [look.body.base.opacity(0.28), look.body.base.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                Ellipse()
                    .fill(Tint.leaf.color.opacity(0.22))
                    .frame(width: 300, height: 70)
                    .offset(y: 38)
                CreatureView(look: look, stage: store.stage, expression: expression, hopTrigger: hop, size: 176) {
                    Haptics.soft()
                    say(Lines.pokes.randomElement()!)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { creatureFrame.rect = $0 }
                .padding(.bottom, 2)
            }
            .frame(height: 196)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .bottom) {
                HeartBurst(trigger: burst)
                    .offset(y: -100)
            }
            .overlay(alignment: .topLeading) {
                if let speech {
                    SpeechBubble(text: speech)
                        .id(speechID)
                        .padding(.leading, 16)
                        .padding(.top, 14)
                        .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.edge, lineWidth: 2))

            levelRow
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var levelRow: some View {
        let info = store.levelInfo
        return HStack(spacing: 12) {
            Text("LV \(info.level)")
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Palette.goldShade))
                .contentTransition(.numericText())
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(store.look.name) · \(store.stage.title)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(info.into)/\(info.needed) XP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.inkSoft)
                        .contentTransition(.numericText())
                }
                XPBar(info: info, height: 14)
                if let next = store.nextMilestone {
                    HStack(spacing: 5) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(Tint.plum.color)
                        (Text("Next unlock: ") + Text(next.headline).fontWeight(.heavy) + Text(" at Lv \(next.level)"))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 4)
                        Text("\(next.xpToGo) XP to go")
                            .foregroundStyle(Palette.inkSoft)
                            .contentTransition(.numericText())
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: info)
    }

    // MARK: Checklist

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeekCard()
                .padding(.bottom, 8)

            HStack {
                Text("Today's list")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(store.doneToday) of \(store.data.habits.count)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .contentTransition(.numericText())
            }
            .padding(.top, 4)

            ForEach(store.data.habits) { habit in
                TaskRow(habit: habit, done: store.isDone(habit)) { origin in
                    tapped(habit, at: origin)
                }
                .contextMenu {
                    if store.isDone(habit) {
                        Button("Mark as not done", systemImage: "arrow.uturn.backward") {
                            withAnimation(.spring) { store.undo(habit) }
                        }
                    }
                }
            }

            if store.allDoneToday {
                perfectDayCard
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            if store.data.habits.isEmpty {
                Button("Add your first habit") { showEditor = true }
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: store.allDoneToday)
    }

    private var perfectDayCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.gold)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Perfect day")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Everything's done. Rest is part of it too.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .chunkyCard(fill: Palette.gold.opacity(0.18))
    }

    // MARK: Effects layer

    private var effects: some View {
        ZStack {
            ForEach(orbs) { orb in
                XPFloater(orb: orb)
                OrbView(orb: orb) { land(orb) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Actions

    @ViewBuilder
    private func flow(for habit: Habit) -> some View {
        switch habit.kind {
        case .checkIn: CheckInFlow { finishFlow(habit) }
        case .breathe: BreatheFlow { finishFlow(habit) }
        case .gratitude: GratitudeFlow { finishFlow(habit) }
        case .simple: EmptyView()
        }
    }

    private func tapped(_ habit: Habit, at origin: CGPoint) {
        guard !store.isDone(habit) else {
            Haptics.soft()
            hop += 1
            say("Already done! Long-press to undo.")
            return
        }
        if habit.kind == .simple {
            reward(habit, from: origin)
        } else {
            Haptics.soft()
            pendingOrigin = origin
            sheetHabit = habit
        }
    }

    private func finishFlow(_ habit: Habit) {
        sheetHabit = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            reward(habit, from: pendingOrigin)
        }
    }

    private func reward(_ habit: Habit, from origin: CGPoint) {
        Haptics.tap()
        let result = withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { store.complete(habit) }

        let landing: Double
        if reduceMotion || origin == .zero {
            landing = 0.1
        } else {
            orbs.append(Orb(from: origin, to: creatureFrame.center, color: habit.tint.color, xp: result.xp))
            landing = 0.56
        }

        Task {
            try? await Task.sleep(for: .seconds(landing))
            say(Lines.afterCompleting(habit))
            if result.weeklyGoal {
                try? await Task.sleep(for: .milliseconds(500))
                show(Banner(symbol: "trophy.fill", tint: .marigold, title: "Weekly goal reached!",
                            detail: "\(AppStore.weeklyGoalDays) days tended this week. +\(AppStore.weeklyBonus) bonus XP."))
                burst += 1
            } else if result.perfectDay {
                try? await Task.sleep(for: .milliseconds(500))
                show(Banner(symbol: "sun.max.fill", tint: .marigold, title: "Perfect day",
                            detail: "Everything on your list, done."))
                say(Lines.greeting(done: 1, total: 1, name: store.look.name))
            }
            if let level = result.newLevel {
                try? await Task.sleep(for: .milliseconds(800))
                withAnimation(.easeOut(duration: 0.25)) { store.levelUpToShow = level }
            }
        }
    }

    /// Orb reached the companion: it catches it and celebrates.
    private func land(_ orb: Orb) {
        orbs.removeAll { $0.id == orb.id }
        hop += 1
        burst += 1
        Haptics.success()
        cheering = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            cheering = false
        }
    }

    private func show(_ new: Banner) {
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { banner = new }
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            if banner?.id == new.id {
                withAnimation(.easeIn(duration: 0.25)) { banner = nil }
            }
        }
    }

    private func say(_ text: String) {
        speechID += 1
        let id = speechID
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { speech = text }
        Task {
            try? await Task.sleep(for: .seconds(2.8))
            if speechID == id {
                withAnimation(.easeOut(duration: 0.2)) { speech = nil }
            }
        }
    }
}

// MARK: Row

struct TaskRow: View {
    var habit: Habit
    var done: Bool
    var onTap: (CGPoint) -> Void

    @State private var checkFrame = FrameBox()

    var body: some View {
        Button {
            onTap(checkFrame.center)
        } label: {
            HStack(spacing: 14) {
                IconTile(symbol: habit.symbol, tint: habit.tint, bounce: done)
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(done ? "Done · +\(habit.xp) XP" : habit.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(done ? habit.tint.shade : Palette.inkSoft)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 8)
                CheckBubble(done: done, tint: habit.tint, opensFlow: habit.kind != .simple)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { checkFrame.rect = $0 }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChunkyCardStyle(
            wash: done ? habit.tint.color.opacity(0.1) : .clear,
            edge: done ? habit.tint.color.opacity(0.55) : Palette.edge))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: done)
        .accessibilityLabel(habit.title)
        .accessibilityValue(done ? "Done" : "Not done")
        .accessibilityHint(done ? "" : habit.kind == .simple ? "Marks it done" : "Opens a short guided activity")
    }
}

struct CheckBubble: View {
    var done: Bool
    var tint: Tint
    var opensFlow = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.track, lineWidth: 3)
                .opacity(done ? 0 : 1)
            if opensFlow && !done {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Palette.inkSoft)
            }
            Circle()
                .fill(tint.color)
                .scaleEffect(done ? 1 : 0.2)
                .opacity(done ? 1 : 0)
            CheckShape()
                .trim(from: 0, to: done ? 1 : 0)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 15, height: 11)
        }
        .frame(width: 34, height: 34)
        .keyframeAnimator(initialValue: 1.0, trigger: done) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(done ? 1.35 : 1, duration: 0.12)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .background {
            Circle()
                .stroke(tint.color, lineWidth: 3)
                .keyframeAnimator(initialValue: RingPulse(), trigger: done) { content, ring in
                    content.scaleEffect(ring.scale).opacity(ring.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: 0.01)
                        CubicKeyframe(done ? 2.1 : 1, duration: 0.5)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(done ? 0.9 : 0, duration: 0.01)
                        CubicKeyframe(0, duration: 0.5)
                    }
                }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: done)
    }
}

private struct RingPulse {
    var scale: CGFloat = 1
    var opacity: Double = 0
}
