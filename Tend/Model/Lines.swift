import Foundation

/// Everything the companion says. Short, warm, never preachy.
enum Lines {
    static func afterCompleting(_ habit: Habit) -> String {
        let pool: [String]
        switch habit.kind {
        case .checkIn:
            pool = ["Thanks for telling me how you feel.", "Feelings noticed. That's the hard part.", "I'm glad you checked in."]
        case .breathe:
            pool = ["Ahh. Lighter already.", "Slow breaths, soft brain.", "That was nice. Let's do it again tomorrow."]
        case .gratitude:
            pool = ["Those are good things.", "I'm keeping those in my pocket.", "Good things, collected!"]
        case .simple:
            pool = ["Nice one!", "That counts. Truly.", "Look at you go!", "Small step, real difference.", "I felt that one!", "Ooh, that tickled my leaf."]
        }
        return pool.randomElement()!
    }

    static let pokes = ["hehe", "that tickles!", "boop.", "hi hi hi", "I'm proud of you, you know.", "squish!", "again!", "*happy wiggle*"]

    static func greeting(done: Int, total: Int, name: String) -> String {
        if total == 0 { return "Add something small to your list?" }
        if done == total { return "A perfect day. I'm glowing!" }
        if done == 0 {
            let hour = Calendar.current.component(.hour, from: .now)
            if hour < 12 { return "Mmh... morning. Start with something tiny?" }
            if hour < 18 { return "Hi! Want to pick one easy thing?" }
            return "Evening! Even one thing counts."
        }
        if Double(done) / Double(total) >= 0.5 { return "We're on a roll." }
        return "That's a start. I'm awake now!"
    }

    static let lockedNudge = "Not yet! Keep tending and we'll get there."
}
