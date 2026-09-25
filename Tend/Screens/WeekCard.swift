import SwiftUI

/// This week's goal: tend enough days to earn the weekly bonus.
struct WeekCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let days = store.weekDays(containing: .now)
        let tended = store.tendedDays(inWeekOf: .now)
        let goal = AppStore.weeklyGoalDays
        let met = store.weeklyGoalMet(inWeekOf: .now)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.caption.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(Palette.inkSoft)
                    Text(met ? "Goal reached!" : "\(min(tended, goal)) of \(goal) days")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: met ? "checkmark.seal.fill" : "trophy.fill")
                    Text("+\(AppStore.weeklyBonus) XP")
                }
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(met ? .white : Palette.goldShade)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(met ? Palette.goldShade : Palette.gold.opacity(0.18)))
            }

            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayRing(
                        fraction: min(1, Double(store.completedCount(on: day)) / Double(store.dailyTargetCount)),
                        tended: store.isTended(day),
                        isToday: Calendar.current.isDateInToday(day),
                        isFuture: day > .now,
                        letter: day.formatted(.dateTime.weekday(.narrow)))
                    .frame(maxWidth: .infinity)
                }
            }

            Text(met
                 ? "Bonus earned. Anything more this week is extra credit."
                 : "A day counts once you finish \(store.dailyTargetCount) things. Tend \(goal) days this week for the bonus.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .chunkyCard(fill: met ? Palette.gold.opacity(0.12) : Palette.card)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: tended)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week: \(tended) of \(goal) days tended. \(met ? "Weekly goal reached." : "")")
    }
}

/// A day in the week strip: ring fills toward the daily target, then turns into a check.
struct DayRing: View {
    var fraction: Double
    var tended: Bool
    var isToday: Bool
    var isFuture: Bool
    var letter: String
    var size: CGFloat = 34

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Palette.track, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: tended ? 1 : fraction)
                    .stroke(Tint.leaf.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if tended {
                    Circle().fill(Tint.leaf.color).padding(5)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.36, weight: .black))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .opacity(isFuture ? 0.45 : 1)
            .scaleEffect(isToday ? 1.08 : 1)
            Text(letter)
                .font(.caption.weight(.heavy))
                .foregroundStyle(isToday ? Palette.ink : Palette.inkSoft)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(isToday ? Palette.track : .clear))
        }
    }
}
