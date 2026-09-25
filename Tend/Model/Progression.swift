import SwiftUI

protocol Unlockable: CaseIterable, Identifiable, Hashable {
    var unlockLevel: Int { get }
    var label: String { get }
}

extension Unlockable where Self: RawRepresentable, RawValue == String {
    var id: String { rawValue }
}

enum BodyColor: String, Codable, Unlockable {
    case mint, peach, sky, butter, lilac, rose, midnight

    var label: String { rawValue.capitalized }

    var unlockLevel: Int {
        switch self {
        case .mint, .peach, .sky: 1
        case .butter: 3
        case .lilac: 6
        case .rose: 9
        case .midnight: 14
        }
    }

    var base: Color {
        switch self {
        case .mint: Color(hex: 0x7ED9A6)
        case .peach: Color(hex: 0xFFB38A)
        case .sky: Color(hex: 0x8CC8FF)
        case .butter: Color(hex: 0xFFD966)
        case .lilac: Color(hex: 0xC3A6FF)
        case .rose: Color(hex: 0xFF9EC0)
        case .midnight: Color(hex: 0x5A6AA0)
        }
    }

    var shade: Color {
        switch self {
        case .mint: Color(hex: 0x4FB07F)
        case .peach: Color(hex: 0xE8855A)
        case .sky: Color(hex: 0x5A9FE0)
        case .butter: Color(hex: 0xE0B23A)
        case .lilac: Color(hex: 0x9A7AE0)
        case .rose: Color(hex: 0xE06F98)
        case .midnight: Color(hex: 0x36406E)
        }
    }

    var belly: Color {
        switch self {
        case .mint: Color(hex: 0xC9F2DA)
        case .peach: Color(hex: 0xFFE0CC)
        case .sky: Color(hex: 0xD6ECFF)
        case .butter: Color(hex: 0xFFF1BF)
        case .lilac: Color(hex: 0xE9DEFF)
        case .rose: Color(hex: 0xFFD9E6)
        case .midnight: Color(hex: 0x98A5D6)
        }
    }

    /// Eye and mouth color. Midnight needs a deeper ink to keep contrast.
    var ink: Color {
        self == .midnight ? Color(hex: 0x12152A) : Color(hex: 0x2B2420)
    }
}

enum EyeStyle: String, Codable, Unlockable {
    case round, bead, sparkle, star

    var label: String {
        switch self {
        case .round: "Round"
        case .bead: "Button"
        case .sparkle: "Sparkly"
        case .star: "Starry"
        }
    }

    var unlockLevel: Int {
        switch self {
        case .round, .bead: 1
        case .sparkle: 4
        case .star: 10
        }
    }
}

enum Pattern: String, Codable, Unlockable {
    case plain, belly, freckles, spots

    var label: String { rawValue.capitalized }

    var unlockLevel: Int {
        switch self {
        case .plain: 1
        case .belly: 2
        case .freckles: 5
        case .spots: 8
        }
    }
}

enum Accessory: String, Codable, Unlockable {
    case none, bow, beanie, glasses, headphones, crown

    var label: String {
        switch self {
        case .none: "Nothing"
        case .headphones: "Headphones"
        default: rawValue.capitalized
        }
    }

    var unlockLevel: Int {
        switch self {
        case .none: 1
        case .bow: 2
        case .beanie: 4
        case .glasses: 7
        case .headphones: 11
        case .crown: 16
        }
    }
}

struct CreatureLook: Codable, Equatable {
    var name = "Pip"
    var body = BodyColor.mint
    var eyes = EyeStyle.round
    var pattern = Pattern.plain
    var accessory = Accessory.none
}

/// The companion's visible growth. Each stage adds something to the sprout on its head.
enum Stage: Int, CaseIterable, Comparable, Identifiable {
    case seedling, sprout, bud, bloom, radiant, legendary

    var id: Int { rawValue }

    static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }

    static func forLevel(_ level: Int) -> Stage {
        allCases.last { level >= $0.minLevel } ?? .seedling
    }

    var minLevel: Int {
        switch self {
        case .seedling: 1
        case .sprout: 3
        case .bud: 5
        case .bloom: 8
        case .radiant: 12
        case .legendary: 16
        }
    }

    var title: String {
        switch self {
        case .seedling: "Seedling"
        case .sprout: "Sprout"
        case .bud: "Budding"
        case .bloom: "In Bloom"
        case .radiant: "Radiant"
        case .legendary: "Legendary"
        }
    }

    var blurb: String {
        switch self {
        case .seedling: "Tiny, new, and already trying."
        case .sprout: "A second leaf. Roots are taking hold."
        case .bud: "Something's getting ready to open."
        case .bloom: "Fully in flower. Look at that."
        case .radiant: "Glowing from the inside out."
        case .legendary: "Sparkles follow them everywhere now."
        }
    }

    /// The companion physically grows a little with each stage.
    var scale: CGFloat {
        switch self {
        case .seedling: 0.8
        case .sprout: 0.86
        case .bud: 0.91
        case .bloom: 0.95
        case .radiant, .legendary: 1
        }
    }
}

struct LevelInfo: Equatable {
    var level: Int
    var into: Int
    var needed: Int
    var fraction: Double { Double(into) / Double(needed) }
}

enum Leveling {
    /// XP to go from `level` to `level + 1`. A full default day is ~100 XP,
    /// so early levels arrive daily and later ones take a few days each.
    static func cost(from level: Int) -> Int { 60 + (level - 1) * 20 }

    /// Total XP needed to reach `level` from zero.
    static func xpAt(level: Int) -> Int {
        (1..<max(1, level)).reduce(0) { $0 + cost(from: $1) }
    }

    static func info(totalXP: Int) -> LevelInfo {
        var level = 1
        var remaining = totalXP
        while remaining >= cost(from: level) {
            remaining -= cost(from: level)
            level += 1
        }
        return LevelInfo(level: level, into: remaining, needed: cost(from: level))
    }
}

struct Unlock: Identifiable, Hashable {
    var id: String { kind + name }
    let kind: String
    let name: String
    let symbol: String
}

enum Unlocks {
    static func at(level: Int) -> [Unlock] {
        var out: [Unlock] = []
        if level > 1, let stage = Stage.allCases.first(where: { $0.minLevel == level }) {
            out.append(Unlock(kind: "Evolution", name: stage.title, symbol: "leaf.fill"))
        }
        out += BodyColor.allCases.filter { $0.unlockLevel == level && level > 1 }
            .map { Unlock(kind: "Color", name: $0.label, symbol: "paintpalette.fill") }
        out += EyeStyle.allCases.filter { $0.unlockLevel == level && level > 1 }
            .map { Unlock(kind: "Eyes", name: $0.label, symbol: "eye.fill") }
        out += Pattern.allCases.filter { $0.unlockLevel == level && level > 1 }
            .map { Unlock(kind: "Pattern", name: $0.label, symbol: "circle.hexagongrid.fill") }
        out += Accessory.allCases.filter { $0.unlockLevel == level && level > 1 }
            .map { Unlock(kind: "Accessory", name: $0.label, symbol: "tshirt.fill") }
        return out
    }

    static func next(after level: Int) -> (level: Int, items: [Unlock])? {
        for candidate in (level + 1)...(level + 20) {
            let items = at(level: candidate)
            if !items.isEmpty { return (candidate, items) }
        }
        return nil
    }
}
