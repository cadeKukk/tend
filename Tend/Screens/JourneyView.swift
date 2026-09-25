import SwiftUI

struct JourneyView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Journey")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 8)

                stats
                evolution
                weeks
                moodWeek
                activity
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    // MARK: Stats

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            StatTile(symbol: "flame.fill", color: Palette.flame, value: store.currentStreak, label: "day streak")
            StatTile(symbol: "trophy.fill", color: Palette.goldShade, value: store.longestStreak, label: "best streak")
            StatTile(symbol: "bolt.fill", color: Palette.gold, value: store.totalXP, label: "total XP")
            StatTile(symbol: "rosette", color: Tint.plum.color, value: store.weeklyGoalsHit, label: "weekly goals")
        }
    }

    // MARK: Mood this week

    private var lastSevenDays: [Date] {
        (0..<7).reversed().map { Day.shift(.now, by: -$0) }
    }

    private var moodWeek: some View {
        card("How you've been") {
            HStack(spacing: 0) {
                ForEach(lastSevenDays, id: \.self) { day in
                    let isToday = Calendar.current.isDateInToday(day)
                    VStack(spacing: 8) {
                        if let entry = store.mood(on: day) {
                            MoodFace(mood: entry.mood, size: 36)
                        } else {
                            Circle()
                                .strokeBorder(Palette.track, style: StrokeStyle(lineWidth: 2.5, dash: [4, 4]))
                                .frame(width: 32, height: 32)
                                .frame(height: 32.4)
                        }
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(isToday ? Palette.ink : Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(store.mood(on: day)?.mood.label ?? "no check-in")")
                }
            }
        }
    }

    // MARK: Activity grid

    private var activity: some View {
        let days = (0..<35).reversed().map { Day.shift(.now, by: -$0) }
        let total = max(1, store.data.habits.count)
        return card("Last five weeks") {
            VStack(alignment: .trailing, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        let fraction = min(1, Double(store.completedCount(on: day)) / Double(total))
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(fraction == 0 ? Palette.track : Tint.leaf.color.opacity(0.25 + 0.75 * fraction))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if Calendar.current.isDateInToday(day) {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Palette.ink, lineWidth: 2)
                                }
                            }
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Activity over the last five weeks")
                HStack(spacing: 4) {
                    Text("less")
                    ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { f in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(f == 0 ? Palette.track : Tint.leaf.color.opacity(0.25 + 0.75 * f))
                            .frame(width: 12, height: 12)
                    }
                    Text("more")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    // MARK: Evolution path

    private var evolution: some View {
        card("\(store.look.name)'s path") {
            VStack(spacing: 0) {
                ForEach(Stage.allCases) { stage in
                    let reached = store.stage >= stage
                    let current = store.stage == stage
                    HStack(spacing: 14) {
                        CreatureView(look: store.look, stage: stage, expression: reached ? .happy : .sleepy, size: 64, animated: false)
                            .colorMultiply(reached ? .white : .black)
                            .opacity(reached ? 1 : 0.14)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(reached ? stage.title : "???")
                                    .font(.system(.headline, design: .rounded, weight: .heavy))
                                    .foregroundStyle(Palette.ink)
                                if current {
                                    Text("NOW")
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Tint.leaf.color))
                                }
                            }
                            Text(reached ? stage.blurb : "Reach level \(stage.minLevel) to find out.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.inkSoft)
                            if current, let progress = stageProgress {
                                VStack(alignment: .leading, spacing: 3) {
                                    XPBar(info: LevelInfo(level: store.level, into: progress.into, needed: progress.needed), height: 10)
                                    Text("\(progress.needed - progress.into) XP until \(progress.next.title)")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(Palette.goldShade)
                                }
                                .padding(.top, 4)
                            }
                        }
                        Spacer(minLength: 0)
                        Text("Lv \(stage.minLevel)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(reached ? Palette.goldShade : Palette.inkSoft)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background {
                        if current {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Tint.leaf.color.opacity(0.1))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Growth math

    /// XP progress through the current stage toward the next one.
    private var stageProgress: (into: Int, needed: Int, next: Stage)? {
        guard let next = Stage(rawValue: store.stage.rawValue + 1) else { return nil }
        let base = Leveling.xpAt(level: store.stage.minLevel)
        let goal = Leveling.xpAt(level: next.minLevel)
        return (min(goal - base, store.totalXP - base), goal - base, next)
    }

    // MARK: Weekly goals

    private var weeks: some View {
        let starts = (0..<8).reversed().map { AppStore.weekStart(for: Day.shift(.now, by: -7 * $0)) }
        let goal = AppStore.weeklyGoalDays
        return card("Weekly goals") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(starts, id: \.self) { start in
                        let tended = store.tendedDays(inWeekOf: start)
                        let met = store.weeklyGoalMet(inWeekOf: start)
                        let isNow = Calendar.current.isDate(start, equalTo: .now, toGranularity: .weekOfYear)
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.track)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(met ? Palette.gold : Tint.leaf.color.opacity(0.55))
                                    .frame(height: 84 * CGFloat(tended) / 7)
                                if met {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(.white)
                                        .padding(.bottom, 6)
                                }
                            }
                            .frame(height: 84)
                            .overlay(alignment: .bottom) {
                                // Goal line at 5 of 7 days.
                                Rectangle()
                                    .fill(Palette.ink.opacity(0.35))
                                    .frame(height: 2)
                                    .offset(y: -84 * CGFloat(goal) / 7)
                            }
                            .overlay {
                                if isNow {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Palette.ink, lineWidth: 2)
                                }
                            }
                            Text(isNow ? "Now" : start.formatted(.dateTime.month(.defaultDigits).day()))
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(isNow ? Palette.ink : Palette.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Week of \(start.formatted(.dateTime.month().day())): \(tended) days tended\(met ? ", goal met" : "")")
                    }
                }
                Text("Bars show days tended each week. Cross the line (\(goal) days) to earn +\(AppStore.weeklyBonus) XP.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chunkyCard()
    }
}

struct StatTile: View {
    var symbol: String
    var color: Color
    var value: Int
    var label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .chunkyCard(radius: 18)
        .accessibilityElement(children: .combine)
    }
}
