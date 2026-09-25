import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }

    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// Warm paper-and-ink palette. Everything else in the app keys off these.
enum Palette {
    static let paper = Color.adaptive(0xFFF7EA, 0x191613)
    static let card = Color.adaptive(0xFFFFFF, 0x25211D)
    static let edge = Color.adaptive(0xEEDFC9, 0x3A332C)
    static let ink = Color.adaptive(0x2B2420, 0xF6EEE3)
    static let inkSoft = Color.adaptive(0x8C7E71, 0xA89A8C)
    static let track = Color.adaptive(0xF1E5D3, 0x352F29)
    static let flame = Color(hex: 0xFF8A1F)
    static let gold = Color(hex: 0xFFC233)
    static let goldShade = Color(hex: 0xE09A00)
    static let blush = Color(hex: 0xFF7A8A)
    static let petal = Color(hex: 0xFF8FA3)
    static let stem = Color(hex: 0x3E9B4F)
    static let leaf = Color(hex: 0x5BC46A)
}

enum Tint: String, Codable, CaseIterable, Identifiable {
    case coral, marigold, leaf, sky, plum, teal

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .coral: Color(hex: 0xFF6B57)
        case .marigold: Color(hex: 0xFFB320)
        case .leaf: Color(hex: 0x3CC47C)
        case .sky: Color(hex: 0x3FA9F5)
        case .plum: Color(hex: 0x9B6BF2)
        case .teal: Color(hex: 0x1FC2B4)
        }
    }

    /// Darker partner used for the chunky "lip" under buttons and tiles.
    var shade: Color {
        switch self {
        case .coral: Color(hex: 0xD9493A)
        case .marigold: Color(hex: 0xD68F00)
        case .leaf: Color(hex: 0x28985C)
        case .sky: Color(hex: 0x2381C9)
        case .plum: Color(hex: 0x7646C9)
        case .teal: Color(hex: 0x14978B)
        }
    }
}
