import SwiftUI
import UIKit

// MARK: Chunky, pressable surfaces

/// Big primary button with a solid lip underneath that it presses down into.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Tint.leaf.color
    var shade: Color = Tint.leaf.shade
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(configuration: configuration, color: color, shade: shade, foreground: foreground)
    }
}

private struct ChunkyButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let color: Color
    let shade: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let pressed = configuration.isPressed
        let fill = isEnabled ? color : Palette.track
        let lip = isEnabled ? shade : Palette.edge
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(isEnabled ? foreground : Palette.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fill))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(lip).offset(y: pressed ? 0 : 5))
            .offset(y: pressed ? 5 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// Card-shaped button: bordered, with a lip, sinks on press.
struct ChunkyCardStyle: ButtonStyle {
    var fill: Color = Palette.card
    var wash: Color = .clear
    var edge: Color = Palette.edge
    var radius: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .background(shape.fill(fill).overlay(shape.fill(wash)))
            .overlay(shape.strokeBorder(edge, lineWidth: 2))
            .background(shape.fill(edge).offset(y: pressed ? 0 : 4))
            .offset(y: pressed ? 4 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

extension View {
    /// Static version of the chunky card for non-interactive panels.
    func chunkyCard(radius: CGFloat = 22, fill: Color = Palette.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Palette.edge, lineWidth: 2))
            .background(shape.fill(Palette.edge).offset(y: 4))
    }
}

// MARK: Small pieces

struct IconTile: View {
    var symbol: String
    var tint: Tint
    var size: CGFloat = 48
    var bounce = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: bounce)
            .frame(width: size, height: size)
            .background(shape.fill(tint.color))
            .background(shape.fill(tint.shade).offset(y: 3))
    }
}

struct StatPill: View {
    var symbol: String
    var color: Color
    var text: String
    var bounce: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: bounce)
            Text(text)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Palette.card))
        .overlay(Capsule().strokeBorder(Palette.edge, lineWidth: 2))
    }
}

struct XPBar: View {
    var info: LevelInfo
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let width = max(height, geo.size.width * info.fraction)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(Palette.gold)
                    .frame(width: info.into == 0 ? 0 : width)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.45))
                            .frame(height: height * 0.28)
                            .padding(.horizontal, height * 0.4)
                            .padding(.top, height * 0.2)
                    }
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Level \(info.level), \(info.into) of \(info.needed) XP")
    }
}

/// Face for a mood rating, drawn like a tiny cousin of the companion.
struct MoodFace: View {
    var mood: Mood
    var size: CGFloat = 44

    var body: some View {
        let ink = Color(hex: 0x2B2420)
        ZStack {
            BlobShape().fill(mood.color)
            BlobShape().fill(LinearGradient(
                stops: [.init(color: .clear, location: 0.55), .init(color: mood.shade.opacity(0.8), location: 1)],
                startPoint: .top, endPoint: .bottom))
            HStack(spacing: size * 0.22) {
                Circle().fill(ink).frame(width: size * 0.11)
                Circle().fill(ink).frame(width: size * 0.11)
            }
            .offset(y: size * 0.04)
            SmileShape(curve: mood.curve)
                .stroke(ink, style: StrokeStyle(lineWidth: max(2, size * 0.06), lineCap: .round))
                .frame(width: size * 0.32, height: size * 0.14)
                .offset(y: size * 0.22)
        }
        .frame(width: size, height: size * 0.9)
        .accessibilityLabel(mood.label)
    }
}

/// Wrapping row layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var width: CGFloat = 0
        var items: [(index: Int, x: CGFloat)] = []
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row(y: 0)]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if row.width > 0, row.width + spacing + size.width > width {
                rows.append(Row(y: row.y + row.height + spacing))
                row = rows[rows.count - 1]
            }
            let x = row.width > 0 ? row.width + spacing : 0
            row.items.append((index, x))
            row.width = x + size.width
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// Holds a frame without triggering re-renders when it changes during scrolling.
final class FrameBox {
    var rect: CGRect = .zero
    var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid(_ intensity: CGFloat = 1) { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: intensity) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func nope() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Sheet top bar: close button plus optional step dots.
struct SheetHeader: View {
    var steps: Int = 0
    var current: Int = 0
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Close")
            if steps > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.track)
                        Capsule().fill(Tint.leaf.color)
                            .frame(width: geo.size.width * CGFloat(current + 1) / CGFloat(steps))
                    }
                }
                .frame(height: 14)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: current)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

// MARK: Banner

/// Lightweight celebration for moments that deserve more than a hop but less than confetti.
struct Banner: Identifiable {
    let id = UUID()
    var symbol: String
    var tint: Tint
    var title: String
    var detail: String
}

struct BannerView: View {
    var banner: Banner
    @State private var shine = false

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: banner.symbol, tint: banner.tint, size: 42, bounce: shine)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(banner.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .chunkyCard(radius: 20)
        .onAppear { shine.toggle() }
        .accessibilityElement(children: .combine)
    }
}
