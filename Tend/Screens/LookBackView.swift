import SwiftUI
import Charts

/// Browse past days: a month calendar with a day detail, or a searchable timeline.
struct LookBackView: View {
    @Environment(AppStore.self) private var store

    enum Mode: String, CaseIterable, Identifiable {
        case calendar = "Calendar"
        case timeline = "Timeline"
        var id: String { rawValue }
    }

    @State private var mode = Mode.calendar
    @State private var month = LookBackView.monthStart(for: .now)
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var forward = true

    static func monthStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Look back")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 8)

                PillPicker(selection: $mode, options: Mode.allCases) { $0.rawValue }

                switch mode {
                case .calendar:
                    calendarCard
                    DayDetailCard(date: selected)
                        .id(selected)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    MonthSummaryCard(month: month)
                case .timeline:
                    TimelineList { date in
                        jump(to: date)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.paper.ignoresSafeArea())
        #if DEBUG
        .onAppear {
            // `-lookback timeline` or `-lookback <days ago>` for screenshots.
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-lookback"), i + 1 < args.count else { return }
            if args[i + 1] == "timeline" { mode = .timeline }
            if let back = Int(args[i + 1]) { selected = Calendar.current.startOfDay(for: Day.shift(.now, by: -back)) }
        }
        #endif
    }

    private func jump(to date: Date) {
        forward = date > month
        month = Self.monthStart(for: date)
        selected = Calendar.current.startOfDay(for: date)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { mode = .calendar }
    }

    // MARK: Calendar

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func changeMonth(by delta: Int) {
        guard delta < 0 || !isCurrentMonth else {
            Haptics.nope()
            return
        }
        Haptics.soft()
        forward = delta > 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            month = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month
            // Keep a sensible day selected in the new month.
            let today = Calendar.current.startOfDay(for: .now)
            selected = Calendar.current.isDate(month, equalTo: today, toGranularity: .month)
                ? today
                : Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.date(byAdding: .month, value: 1, to: month)!)!
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks then every day of the month.
    private var cells: [Date?] {
        let cal = Calendar.current
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + (0..<count).map { Day.shift(month, by: $0) }
    }

    private var calendarCard: some View {
        VStack(spacing: 14) {
            HStack {
                monthButton("chevron.left", label: "Previous month") { changeMonth(by: -1) }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                Spacer()
                monthButton("chevron.right", label: "Next month") { changeMonth(by: 1) }
                    .opacity(isCurrentMonth ? 0.3 : 1)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
            .id(month)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            .clipped()
            .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.width < -50 { changeMonth(by: 1) }
                if value.translation.width > 50 { changeMonth(by: -1) }
            })

            HStack(spacing: 14) {
                legendDot(Tint.leaf.color, "did something")
                HStack(spacing: 4) {
                    MoodFace(mood: .good, size: 14)
                    Text("checked in")
                }
                Spacer()
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Palette.inkSoft)
        }
        .padding(16)
        .chunkyCard()
    }

    private func monthButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.track))
        }
        .accessibilityLabel(label)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selected)
        let isFuture = date > .now && !isToday
        let mood = store.mood(on: date)
        let done = store.completedCount(on: date)
        let fraction = min(1, Double(done) / Double(max(1, store.data.habits.count)))

        return Button {
            Haptics.soft()
            selected = cal.startOfDay(for: date)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if let mood {
                        MoodFace(mood: mood.mood, size: 28)
                    } else if done > 0 {
                        Circle()
                            .fill(Tint.leaf.color.opacity(0.3 + 0.7 * fraction))
                            .frame(width: 14, height: 14)
                    } else {
                        Circle().fill(Palette.track).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 26)
                Text("\(cal.component(.day, from: date))")
                    .font(.caption2.weight(isToday ? .black : .bold))
                    .foregroundStyle(isToday ? Tint.leaf.shade : Palette.inkSoft)
                Capsule()
                    .fill(done > 0 ? Tint.leaf.color : .clear)
                    .frame(width: store.isTended(date) ? 16 : 6, height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Tint.leaf.color.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tint.leaf.color, lineWidth: 2))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.3 : 1)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue([mood.map { "Felt \($0.mood.label)" }, done > 0 ? "\(done) things done" : nil].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Day detail

struct DayDetailCard: View {
    var date: Date
    @Environment(AppStore.self) private var store

    var body: some View {
        let habits = store.habitsDone(on: date)
        let moods = store.moods(on: date)
        let good = store.gratitude(on: date)
        let xp = store.xpEarned(on: date)
        let empty = habits.isEmpty && moods.isEmpty && good.isEmpty

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Calendar.current.isDateInToday(date) ? "TODAY" : date.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.caption.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(Palette.inkSoft)
                    Text(date.formatted(.dateTime.month(.wide).day().year()))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                if xp > 0 {
                    Text("+\(xp) XP")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.goldShade)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.gold.opacity(0.18)))
                }
            }

            if empty {
                HStack(spacing: 12) {
                    CreatureView(look: store.look, stage: store.stage, expression: .sleepy, size: 64, animated: false)
                    Text(Calendar.current.isDateInToday(date) ? "Nothing yet today. Plenty of time." : "Nothing logged this day. Rest days are allowed.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }

            if !moods.isEmpty {
                section(moods.count == 1 ? "How you felt" : "How you felt (\(moods.count) check-ins)") {
                    ForEach(moods) { MoodEntryRow(entry: $0) }
                }
            }

            if !good.isEmpty {
                section("Good things") {
                    ForEach(good) { GoodThingsRow(entry: $0) }
                }
            }

            if !habits.isEmpty {
                section("Things you did · \(habits.count)") {
                    FlowLayout(spacing: 6) {
                        ForEach(habits) { habit in
                            HStack(spacing: 5) {
                                Image(systemName: habit.symbol)
                                    .foregroundStyle(habit.tint.color)
                                Text(habit.title)
                                    .foregroundStyle(Palette.ink)
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(habit.tint.color.opacity(0.12)))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chunkyCard()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.black))
                .tracking(0.6)
                .foregroundStyle(Palette.inkSoft)
            content()
        }
    }
}

struct MoodEntryRow: View {
    var entry: MoodEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MoodFace(mood: entry.mood, size: 40)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.mood.label)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                if !entry.feelings.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(entry.feelings, id: \.self) { word in
                            Text(word)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(entry.mood.shade)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(entry.mood.color.opacity(0.2)))
                        }
                    }
                }
                if !entry.note.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Capsule().fill(entry.mood.color).frame(width: 3)
                        Text(entry.note)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct GoodThingsRow: View {
    var entry: GratitudeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(entry.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Tint.marigold.color))
                    Text(item)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Month summary

struct MonthSummaryCard: View {
    var month: Date
    @Environment(AppStore.self) private var store

    private var days: [Date] {
        let count = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? 30
        return (0..<count).map { Day.shift(month, by: $0) }.filter { $0 <= .now }
    }

    var body: some View {
        let days = self.days
        let moods = days.flatMap { store.moods(on: $0) }
        let goodCount = days.reduce(0) { total, day in total + store.gratitude(on: day).reduce(0) { $0 + $1.items.count } }
        let tended = days.filter(store.isTended).count
        let monthName = month.formatted(.dateTime.month(.wide))

        VStack(alignment: .leading, spacing: 18) {
            Text("\(monthName) at a glance")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 10) {
                miniStat("\(tended)", "days tended", Tint.leaf)
                miniStat("\(moods.count)", "check-ins", .coral)
                miniStat("\(goodCount)", "good things", .marigold)
            }

            if moods.count >= 2 {
                trend(moods)
                mix(moods)
            }

            let top = topFeelings(moods)
            if !top.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FELT MOST OFTEN")
                        .font(.caption.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkSoft)
                    FlowLayout(spacing: 6) {
                        ForEach(top, id: \.word) { item in
                            HStack(spacing: 4) {
                                Text(item.word)
                                Text("×\(item.count)").foregroundStyle(Palette.inkSoft)
                            }
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Palette.track))
                        }
                    }
                }
            }

            if moods.isEmpty && tended == 0 {
                Text("Nothing logged in \(monthName) yet.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chunkyCard()
    }

    private func miniStat(_ value: String, _ label: String, _ tint: Tint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(tint.shade)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.color.opacity(0.1)))
    }

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
        var mood: Mood { Mood(rawValue: Int(value.rounded())) ?? .okay }
    }

    private func trend(_ moods: [MoodEntry]) -> some View {
        let grouped = Dictionary(grouping: moods) { Calendar.current.startOfDay(for: $0.date) }
        let points = grouped.map { day, entries in
            Point(date: day, value: Double(entries.map(\.mood.rawValue).reduce(0, +)) / Double(entries.count))
        }
        .sorted { $0.date < $1.date }
        let end = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month

        return VStack(alignment: .leading, spacing: 8) {
            Text("MOOD OVER THE MONTH")
                .font(.caption.weight(.black))
                .tracking(0.6)
                .foregroundStyle(Palette.inkSoft)
            Chart(points) { point in
                LineMark(x: .value("Day", point.date, unit: .day), y: .value("Mood", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Palette.inkSoft.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Day", point.date, unit: .day), y: .value("Mood", point.value))
                    .foregroundStyle(point.mood.color)
                    .symbolSize(90)
            }
            .chartYScale(domain: 0.6...5.4)
            .chartXScale(domain: month...end)
            .chartYAxis {
                AxisMarks(position: .leading, values: [1, 3, 5]) { value in
                    AxisGridLine().foregroundStyle(Palette.track)
                    AxisValueLabel {
                        if let raw = value.as(Int.self), let mood = Mood(rawValue: raw) {
                            MoodFace(mood: mood, size: 18)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(height: 150)
            .accessibilityLabel("Mood trend for the month")
        }
    }

    private func mix(_ moods: [MoodEntry]) -> some View {
        let counts = Mood.allCases.map { mood in (mood, moods.filter { $0.mood == mood }.count) }.filter { $0.1 > 0 }
        let total = Double(moods.count)
        return VStack(alignment: .leading, spacing: 8) {
            Text("MOOD MIX")
                .font(.caption.weight(.black))
                .tracking(0.6)
                .foregroundStyle(Palette.inkSoft)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(counts, id: \.0) { mood, count in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(mood.color)
                            .frame(width: max(6, (geo.size.width - CGFloat(counts.count - 1) * 3) * CGFloat(Double(count) / total)))
                    }
                }
            }
            .frame(height: 16)
            HStack(spacing: 12) {
                ForEach(counts, id: \.0) { mood, count in
                    HStack(spacing: 4) {
                        MoodFace(mood: mood, size: 16)
                        Text("\(count)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(counts.map { "\($0.0.label): \($0.1)" }.joined(separator: ", "))
    }

    private func topFeelings(_ moods: [MoodEntry]) -> [(word: String, count: Int)] {
        var tally: [String: Int] = [:]
        for word in moods.flatMap(\.feelings) { tally[word, default: 0] += 1 }
        return tally.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(6)
            .map { (word: $0.key, count: $0.value) }
    }
}

// MARK: Timeline

struct TimelineList: View {
    var onOpenDay: (Date) -> Void
    @Environment(AppStore.self) private var store

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Everything"
        case feelings = "Feelings"
        case good = "Good things"
        var id: String { rawValue }
    }

    @State private var filter = Filter.all
    @State private var query = ""

    private struct DayGroup: Identifiable {
        let date: Date
        var moods: [MoodEntry]
        var good: [GratitudeEntry]
        var id: Date { date }
    }

    private var groups: [DayGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let moods = filter == .good ? [] : store.data.moods.filter { entry in
            q.isEmpty || entry.note.lowercased().contains(q) || entry.mood.label.lowercased().contains(q)
                || entry.feelings.contains { $0.lowercased().contains(q) }
        }
        let good = filter == .feelings ? [] : store.data.gratitude.filter { entry in
            q.isEmpty || entry.items.contains { $0.lowercased().contains(q) }
        }
        var byDay: [Date: DayGroup] = [:]
        for m in moods {
            let day = Calendar.current.startOfDay(for: m.date)
            byDay[day, default: DayGroup(date: day, moods: [], good: [])].moods.append(m)
        }
        for g in good {
            let day = Calendar.current.startOfDay(for: g.date)
            byDay[day, default: DayGroup(date: day, moods: [], good: [])].good.append(g)
        }
        return byDay.values.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.inkSoft)
                TextField("Search notes, feelings, good things", text: $query)
                    .font(.body.weight(.medium))
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkSoft)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(14)
            .chunkyCard(radius: 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.allCases) { option in
                        let on = filter == option
                        Button {
                            Haptics.soft()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filter = option }
                        } label: {
                            Text(option.rawValue)
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(on ? .white : Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(ChunkyCardStyle(fill: on ? Palette.ink : Palette.card, edge: on ? Palette.ink.opacity(0.6) : Palette.edge, radius: 14))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.bottom, 4)
            }

            let groups = self.groups
            if groups.isEmpty {
                VStack(spacing: 10) {
                    CreatureView(look: store.look, stage: store.stage, expression: .calm, size: 90, animated: false)
                    Text(query.isEmpty ? "Your check-ins and good things will collect here." : "Nothing matches \u{201C}\(query)\u{201D}.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }

            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            onOpenDay(group.date)
                        } label: {
                            HStack(spacing: 6) {
                                Text(header(for: group.date))
                                    .font(.system(.headline, design: .rounded, weight: .heavy))
                                    .foregroundStyle(Palette.ink)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(Palette.inkSoft)
                                Spacer()
                                let done = store.completedCount(on: group.date)
                                if done > 0 {
                                    Label("\(done) done", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(Tint.leaf.shade)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this day in the calendar")

                        ForEach(group.moods.sorted { $0.date > $1.date }) { entry in
                            MoodEntryRow(entry: entry)
                                .padding(14)
                                .chunkyCard(radius: 18)
                        }
                        ForEach(group.good) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Good things", systemImage: "sparkles")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(Tint.marigold.shade)
                                GoodThingsRow(entry: entry)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .chunkyCard(radius: 18)
                        }
                    }
                }
            }
        }
    }

    private func header(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

// MARK: Pill picker

/// Chunky two-or-three-way segmented control.
struct PillPicker<Option: Hashable>: View {
    @Binding var selection: Option
    var options: [Option]
    var label: (Option) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(on ? Palette.ink : Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Palette.card)
                                    .shadow(color: Palette.edge, radius: 0, x: 0, y: 3)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.track))
    }
}
