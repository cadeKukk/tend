import Foundation
import Observation

@Observable
final class AppStore {
    struct Snapshot: Codable {
        var habits: [Habit] = Habit.starters
        /// Habits removed from the list, kept so history can still name them.
        var retiredHabits: [Habit] = []
        /// day key → habit id → XP earned. XP is stored per completion so
        /// editing or deleting a habit never rewrites history.
        var completions: [String: [String: Int]] = [:]
        /// week key (day key of the week's first day) → bonus XP earned.
        var weeklyBonuses: [String: Int] = [:]
        var moods: [MoodEntry] = []
        var gratitude: [GratitudeEntry] = []
        var look = CreatureLook()
        var hatched = false
        var celebratedLevel = 1

        init() {}

        /// Tolerates missing keys so older saves keep loading as fields are added.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Snapshot()
            habits = try c.decodeIfPresent([Habit].self, forKey: .habits) ?? d.habits
            retiredHabits = try c.decodeIfPresent([Habit].self, forKey: .retiredHabits) ?? d.retiredHabits
            completions = try c.decodeIfPresent([String: [String: Int]].self, forKey: .completions) ?? d.completions
            weeklyBonuses = try c.decodeIfPresent([String: Int].self, forKey: .weeklyBonuses) ?? d.weeklyBonuses
            moods = try c.decodeIfPresent([MoodEntry].self, forKey: .moods) ?? d.moods
            gratitude = try c.decodeIfPresent([GratitudeEntry].self, forKey: .gratitude) ?? d.gratitude
            look = try c.decodeIfPresent(CreatureLook.self, forKey: .look) ?? d.look
            hatched = try c.decodeIfPresent(Bool.self, forKey: .hatched) ?? d.hatched
            celebratedLevel = try c.decodeIfPresent(Int.self, forKey: .celebratedLevel) ?? d.celebratedLevel
        }
    }

    struct Reward {
        var xp: Int
        var newLevel: Int?
        var perfectDay: Bool
        var weeklyGoal: Bool
    }

    /// A day "counts" toward the weekly goal once this many things are done.
    static let dailyTarget = 3
    static let weeklyGoalDays = 5
    static let weeklyBonus = 100

    private(set) var data: Snapshot
    private(set) var todayKey = Day.key(for: .now)

    /// A level-up waiting for the full-screen celebration. UI-only, not persisted.
    var levelUpToShow: Int?

    private static let fileURL = URL.documentsDirectory.appending(path: "tend.json")

    init() {
        if let raw = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: raw) {
            data = saved
        } else {
            data = Snapshot()
        }
        #if DEBUG
        applyLaunchArguments()
        #endif
    }

    // MARK: Levels

    var look: CreatureLook { data.look }

    var totalXP: Int {
        data.completions.values.reduce(0) { $0 + $1.values.reduce(0, +) }
            + data.weeklyBonuses.values.reduce(0, +)
    }

    var levelInfo: LevelInfo { Leveling.info(totalXP: totalXP) }
    var level: Int { levelInfo.level }
    var stage: Stage { .forLevel(level) }

    struct Milestone {
        var level: Int
        var items: [Unlock]
        var xpToGo: Int

        /// The most exciting thing waiting there: an evolution beats a hat.
        var headline: String {
            items.first(where: { $0.kind == "Evolution" }).map { "\($0.name) form" } ?? items.first?.name ?? "A surprise"
        }
    }

    var nextMilestone: Milestone? {
        guard let next = Unlocks.next(after: level) else { return nil }
        return Milestone(level: next.level, items: next.items, xpToGo: max(0, Leveling.xpAt(level: next.level) - totalXP))
    }

    // MARK: Today

    func isDone(_ habit: Habit) -> Bool {
        data.completions[todayKey]?[habit.id.uuidString] != nil
    }

    var doneToday: Int { data.habits.filter(isDone).count }
    var allDoneToday: Bool { !data.habits.isEmpty && doneToday == data.habits.count }

    // MARK: Any day

    func completedCount(on date: Date) -> Int {
        data.completions[Day.key(for: date)]?.count ?? 0
    }

    func xpEarned(on date: Date) -> Int {
        data.completions[Day.key(for: date)]?.values.reduce(0, +) ?? 0
    }

    func habitsDone(on date: Date) -> [Habit] {
        guard let ids = data.completions[Day.key(for: date)]?.keys else { return [] }
        let all = data.habits + data.retiredHabits
        return ids.compactMap { id in all.first { $0.id.uuidString == id } }
            .sorted { $0.title < $1.title }
    }

    func moods(on date: Date) -> [MoodEntry] {
        let key = Day.key(for: date)
        return data.moods.filter { Day.key(for: $0.date) == key }.sorted { $0.date < $1.date }
    }

    func mood(on date: Date) -> MoodEntry? { moods(on: date).last }

    func gratitude(on date: Date) -> [GratitudeEntry] {
        let key = Day.key(for: date)
        return data.gratitude.filter { Day.key(for: $0.date) == key }.sorted { $0.date < $1.date }
    }

    // MARK: Weeks

    /// How many completions make a day count. Never more than the list holds.
    var dailyTargetCount: Int { max(1, min(Self.dailyTarget, data.habits.count)) }

    func isTended(_ date: Date) -> Bool { completedCount(on: date) >= dailyTargetCount }

    static func weekStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start ?? Calendar.current.startOfDay(for: date)
    }

    static func weekKey(for date: Date) -> String { Day.key(for: weekStart(for: date)) }

    func weekDays(containing date: Date) -> [Date] {
        let start = Self.weekStart(for: date)
        return (0..<7).map { Day.shift(start, by: $0) }
    }

    func tendedDays(inWeekOf date: Date) -> Int {
        weekDays(containing: date).filter(isTended).count
    }

    func weeklyGoalMet(inWeekOf date: Date) -> Bool {
        data.weeklyBonuses[Self.weekKey(for: date)] != nil
    }

    var weeklyGoalsHit: Int { data.weeklyBonuses.count }

    /// Grants or revokes this week's bonus so it always matches the actual days.
    /// Returns true when the bonus was newly earned.
    private func syncWeeklyBonus() -> Bool {
        let key = Self.weekKey(for: .now)
        let met = tendedDays(inWeekOf: .now) >= Self.weeklyGoalDays
        if met, data.weeklyBonuses[key] == nil {
            data.weeklyBonuses[key] = Self.weeklyBonus
            return true
        }
        if !met, data.weeklyBonuses[key] != nil {
            data.weeklyBonuses[key] = nil
        }
        return false
    }

    // MARK: Streaks

    private func isActive(_ date: Date) -> Bool { completedCount(on: date) > 0 }

    var currentStreak: Int {
        var day = Date.now
        if !isActive(day) { day = Day.shift(day, by: -1) }
        var count = 0
        while isActive(day) {
            count += 1
            day = Day.shift(day, by: -1)
        }
        return count
    }

    var longestStreak: Int {
        let days = data.completions.filter { !$0.value.isEmpty }.keys.compactMap(Day.date).sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, Calendar.current.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    // MARK: Mutations

    @discardableResult
    func complete(_ habit: Habit) -> Reward {
        guard !isDone(habit) else { return Reward(xp: 0, newLevel: nil, perfectDay: false, weeklyGoal: false) }
        let before = level
        data.completions[todayKey, default: [:]][habit.id.uuidString] = habit.xp
        let weekly = syncWeeklyBonus()
        let after = level
        var newLevel: Int?
        if after > before, after > data.celebratedLevel {
            data.celebratedLevel = after
            newLevel = after
        }
        save()
        return Reward(xp: habit.xp, newLevel: newLevel, perfectDay: allDoneToday, weeklyGoal: weekly)
    }

    func undo(_ habit: Habit) {
        data.completions[todayKey]?[habit.id.uuidString] = nil
        _ = syncWeeklyBonus()
        save()
    }

    func logMood(_ entry: MoodEntry) {
        data.moods.append(entry)
        save()
    }

    func logGratitude(_ items: [String]) {
        data.gratitude.append(GratitudeEntry(date: .now, items: items))
        save()
    }

    func updateLook(_ change: (inout CreatureLook) -> Void) {
        change(&data.look)
        save()
    }

    func hatch(name: String, body: BodyColor) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        data.look.name = trimmed.isEmpty ? "Pip" : trimmed
        data.look.body = body
        data.hatched = true
        save()
    }

    func addHabit(_ habit: Habit) {
        data.habits.append(habit)
        save()
    }

    func removeHabits(at offsets: IndexSet) {
        data.retiredHabits += offsets.map { data.habits[$0] }
        data.habits.remove(atOffsets: offsets)
        save()
    }

    func moveHabits(from source: IndexSet, to destination: Int) {
        data.habits.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func refreshDay() {
        let key = Day.key(for: .now)
        if key != todayKey { todayKey = key }
    }

    private func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("Tend: save failed: \(error)")
        }
    }

    // MARK: Debug seeding

    #if DEBUG
    /// `-reset` starts fresh; `-demo <level>` fills history for previews.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-reset") {
            data = Snapshot()
            save()
        }
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count, let target = Int(args[i + 1]) else { return }
        data = Snapshot()
        data.hatched = true
        if let j = args.firstIndex(of: "-look"), j + 1 < args.count {
            let parts = args[j + 1].split(separator: ",").map(String.init)
            if parts.count == 4 {
                data.look.body = BodyColor(rawValue: parts[0]) ?? .mint
                data.look.eyes = EyeStyle(rawValue: parts[1]) ?? .round
                data.look.pattern = Pattern(rawValue: parts[2]) ?? .plain
                data.look.accessory = Accessory(rawValue: parts[3]) ?? .none
            }
        }
        let notes = ["Long day but I got outside.", "Talked to my sister, felt lighter after.", "", "", "Couldn't sleep well.", "Work was a lot.", ""]
        let good = [["Morning coffee", "A text from Sam", "Finished the book"], ["Sunny walk", "Good lunch", "Dog was extra cuddly"], ["Called mom", "Clean kitchen", "Laughed at a video"]]
        var xpNeeded = Leveling.xpAt(level: max(1, target)) + 20
        var day = Day.shift(.now, by: -1)
        while xpNeeded > 0 {
            let key = Day.key(for: day)
            for habit in data.habits.shuffled().prefix(Int.random(in: 1...8)) where xpNeeded > 0 {
                data.completions[key, default: [:]][habit.id.uuidString] = habit.xp
                xpNeeded -= habit.xp
            }
            if Int.random(in: 0..<10) < 8, let mood = Mood.allCases.randomElement() {
                let at = Calendar.current.date(bySettingHour: Int.random(in: 8...21), minute: Int.random(in: 0...59), second: 0, of: day) ?? day
                data.moods.insert(MoodEntry(date: at, mood: mood, feelings: Array(mood.suggestedFeelings.shuffled().prefix(Int.random(in: 1...3))), note: notes.randomElement()!), at: 0)
            }
            if Bool.random(), let items = good.randomElement() {
                data.gratitude.insert(GratitudeEntry(date: day, items: items), at: 0)
            }
            day = Day.shift(day, by: -1)
        }
        // Award bonuses for past weeks that earned them.
        var week = Self.weekStart(for: Day.shift(.now, by: -7))
        while week > day {
            if tendedDays(inWeekOf: week) >= Self.weeklyGoalDays { data.weeklyBonuses[Day.key(for: week)] = Self.weeklyBonus }
            week = Day.shift(week, by: -7)
        }
        data.celebratedLevel = level
        save()
    }
    #endif
}
