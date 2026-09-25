import SwiftUI

enum HabitKind: String, Codable {
    case simple, checkIn, breathe, gratitude
}

struct Habit: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var symbol: String
    var tint: Tint
    var kind: HabitKind = .simple
    var xp: Int = 10

    /// Same habit with a new identity, so adding an idea twice never collides.
    var fresh: Habit {
        var copy = self
        copy.id = UUID()
        return copy
    }

    static let starters: [Habit] = [
        Habit(title: "Check in with your feelings", subtitle: "Name what's going on inside", symbol: "heart.text.square.fill", tint: .coral, kind: .checkIn, xp: 20),
        Habit(title: "Breathe for a minute", subtitle: "Slow in, slower out", symbol: "wind", tint: .sky, kind: .breathe, xp: 15),
        Habit(title: "Three good things", subtitle: "Notice what went right", symbol: "sparkles", tint: .marigold, kind: .gratitude, xp: 15),
        Habit(title: "Drink a glass of water", subtitle: "Keep one within reach", symbol: "drop.fill", tint: .teal),
        Habit(title: "Get some daylight", subtitle: "Ten minutes outside", symbol: "sun.max.fill", tint: .marigold),
        Habit(title: "Move your body", subtitle: "A walk, a stretch, a dance", symbol: "figure.walk", tint: .leaf),
        Habit(title: "Reach out to someone", subtitle: "A text counts", symbol: "bubble.left.and.bubble.right.fill", tint: .plum),
        Habit(title: "Wind down screen-free", subtitle: "30 minutes before bed", symbol: "moon.stars.fill", tint: .sky),
    ]

    static let ideas: [Habit] = [
        Habit(title: "Take your meds", subtitle: "Future you says thanks", symbol: "pills.fill", tint: .coral),
        Habit(title: "Eat a real meal", subtitle: "Something warm counts double", symbol: "fork.knife", tint: .marigold),
        Habit(title: "Tidy one small thing", subtitle: "One drawer, one surface", symbol: "tray.fill", tint: .teal),
        Habit(title: "Journal for five minutes", subtitle: "No rules, just words", symbol: "book.closed.fill", tint: .plum),
        Habit(title: "Stretch", subtitle: "Neck, shoulders, back", symbol: "figure.cooldown", tint: .leaf),
        Habit(title: "Read something", subtitle: "Ten pages or ten minutes", symbol: "book.fill", tint: .sky),
        Habit(title: "Do something just for fun", subtitle: "No productivity allowed", symbol: "gamecontroller.fill", tint: .teal),
        Habit(title: "Go to bed on time", subtitle: "Sleep is maintenance", symbol: "bed.double.fill", tint: .plum),
    ]

    static let symbolChoices = [
        "star.fill", "leaf.fill", "book.fill", "pencil", "music.note", "paintbrush.fill",
        "dumbbell.fill", "figure.walk", "bed.double.fill", "cup.and.saucer.fill", "fork.knife", "pills.fill",
        "phone.fill", "heart.fill", "hands.sparkles.fill", "pawprint.fill", "camera.fill", "gamecontroller.fill",
        "sun.max.fill", "moon.fill",
    ]
}

enum Mood: Int, CaseIterable, Identifiable, Codable {
    case rough = 1, low, okay, good, great

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .rough: "Rough"
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var color: Color {
        switch self {
        case .rough: Color(hex: 0x8A90B8)
        case .low: Color(hex: 0x74B3E8)
        case .okay: Color(hex: 0xF5CF5A)
        case .good: Color(hex: 0x74D38A)
        case .great: Color(hex: 0xFF9466)
        }
    }

    var shade: Color {
        switch self {
        case .rough: Color(hex: 0x646A94)
        case .low: Color(hex: 0x4A8CC4)
        case .okay: Color(hex: 0xD6A92A)
        case .good: Color(hex: 0x45AA5F)
        case .great: Color(hex: 0xE0663A)
        }
    }

    /// Mouth curve for the little mood face: negative frowns, positive smiles.
    var curve: CGFloat {
        switch self {
        case .rough: -1.1
        case .low: -0.5
        case .okay: 0.05
        case .good: 0.8
        case .great: 1.3
        }
    }

    var companionExpression: CreatureExpression {
        switch self {
        case .rough, .low: .sad
        case .okay: .calm
        case .good: .happy
        case .great: .ecstatic
        }
    }

    var companionReply: String {
        switch self {
        case .rough: "That sounds really hard. I'm right here."
        case .low: "Thanks for being honest with me."
        case .okay: "Okay is a perfectly fine place to be."
        case .good: "Ooh, I like hearing that."
        case .great: "Yes!! Tell me everything!"
        }
    }

    static let pleasant = ["Calm", "Content", "Grateful", "Hopeful", "Proud", "Loved", "Energized", "Playful", "Relieved", "Focused"]
    static let unpleasant = ["Anxious", "Tired", "Overwhelmed", "Sad", "Lonely", "Irritated", "Stressed", "Numb", "Restless", "Ashamed"]

    /// Feeling words, with the ones most likely to fit this mood first.
    var suggestedFeelings: [String] {
        switch self {
        case .rough, .low: Mood.unpleasant + Mood.pleasant
        case .okay: zip(Mood.pleasant, Mood.unpleasant).flatMap { [$0, $1] }
        case .good, .great: Mood.pleasant + Mood.unpleasant
        }
    }
}

struct MoodEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var mood: Mood
    var feelings: [String]
    var note: String
}

struct GratitudeEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var items: [String]
}

enum Day {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String {
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.timeZone = .current
        return formatter.date(from: key)
    }

    static func shift(_ date: Date, by days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}
