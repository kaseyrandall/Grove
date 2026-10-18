import SwiftUI

// MARK: - Match Day: the Arena's look
//
// Condensed, slanted capitals for names and numbers; leaning cards and
// angled buttons; your side in mint, the rival in red, gold for results and
// rewards. Grove's habitat colors still mark each friend.

extension BattleTheme {
    /// The rival's side.
    static let foe  = Color(hex: 0xFF5A5F)
    static let lime = Color(hex: 0xC6FF5C)
    /// The page ground, darkest at the bottom.
    static let night = Color(hex: 0x050C09)
}

extension View {
    /// The Match Day display face: heavy, compressed, italic. Scales with
    /// the player's text size like `arenaFont` (capped; big sizes fixed).
    func arenaDisplay(_ size: CGFloat) -> some View {
        modifier(ArenaDisplayFont(size: size))
    }
}

private struct ArenaDisplayFont: ViewModifier {
    let size: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        // Set each trait on the view too: the app's rounded design (set at the
        // root) would otherwise win, and rounded has no compressed width.
        // The system face has no italic at this width, so lean it with a
        // shear (top to the right), re-centered on the line.
        let lean: CGFloat = 0.16
        content
            .font(.system(size: scaled, weight: .black, design: .default).width(.compressed))
            .fontDesign(.default)
            .fontWeight(.black)
            .fontWidth(.compressed)
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: -lean, d: 1, tx: lean * scaled * 0.6, ty: 0))
    }

    private var scaled: CGFloat {
        guard size < 30 else { return size }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(typeSize))
        let grown = UIFontMetrics(forTextStyle: .body).scaledValue(for: size, compatibleWith: traits)
        return min(grown, size * 1.4)
    }
}

// MARK: - Shapes

/// A leaning four-sided shape: the top edge starts `lead` points in from the
/// left, the bottom edge stops `trail` points short of the right. Zero on
/// either side keeps that corner square.
struct Slant: InsettableShape {
    var lead: CGFloat = 0
    var trail: CGFloat = 0
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + lead, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - trail, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Slant {
        var s = self; s.insetAmount += amount; return s
    }
}

/// A rectangle with its bottom-right corner cut off at 45°, for tall cards
/// (a full-height lean would eat into the content).
struct CutCorner: InsettableShape {
    var cut: CGFloat = 22
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> CutCorner {
        var c = self; c.insetAmount += amount; return c
    }
}

/// A leaning parallelogram, for bars and buttons.
struct Lean: Shape {
    var amount: CGFloat = 6
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + amount, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - amount, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A thin lightning stroke: flat, a sharp zig-zag, flat again.
struct Bolt: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.6))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.37, y: rect.minY + h * 0.6))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.44, y: rect.minY + h * 0.1))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.49, y: rect.minY + h * 0.8))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.55, y: rect.minY + h * 0.35))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.35))
        return p
    }
}

// MARK: - Pieces

/// The page ground: deep green-black, a mint glow at the top and a faint
/// diagonal texture.
struct MatchDayBackdrop: View {
    var glow: Color = BattleTheme.leaf

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1D16), BattleTheme.night], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.14), .clear], center: .top, startRadius: 0, endRadius: 420)
            Canvas { ctx, size in
                var lines = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    lines.move(to: CGPoint(x: x, y: size.height))
                    lines.addLine(to: CGPoint(x: x + size.height * 0.58, y: 0))
                    x += 14
                }
                ctx.stroke(lines, with: .color(.white.opacity(0.018)), lineWidth: 2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// A small slanted tag ("READY", "TYPE EDGE").
struct SlantTag: View {
    let text: String
    var fill: Color = Color(hex: 0x0B1712)
    var ink: Color = BattleTheme.ink
    var outline: Color? = BattleTheme.panelLine
    var size: CGFloat = 12

    var body: some View {
        Text(text.uppercased())
            .arenaDisplay(size)
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(
                Lean(amount: 5).fill(fill)
                    .overlay { if let outline { Lean(amount: 5).stroke(outline, lineWidth: 1.5) } }
            )
    }
}

/// A leaning button face: filled for actions, outlined for status.
struct LeanButtonFace: View {
    let text: String
    var style: Style = .action
    var height: CGFloat = 34
    var size: CGFloat = 15

    enum Style { case action, reward, quiet }

    var body: some View {
        Text(text.uppercased())
            .arenaDisplay(size)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(background)
    }

    private var ink: Color {
        switch style {
        case .action: return Color(hex: 0x04130C)
        case .reward: return Color(hex: 0x120E02)
        case .quiet:  return BattleTheme.ink
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .action:
            Lean(amount: 6).fill(LinearGradient(colors: [BattleTheme.leaf, BattleTheme.leafDeep], startPoint: .top, endPoint: .bottom))
        case .reward:
            Lean(amount: 6).fill(LinearGradient(colors: [Color(hex: 0xFFE07E), Color(hex: 0xF2B73A)], startPoint: .top, endPoint: .bottom))
        case .quiet:
            Lean(amount: 6).fill(.white.opacity(0.05))
                .overlay(Lean(amount: 6).stroke(BattleTheme.panelLine, lineWidth: 1.5))
        }
    }
}

/// A leaning meter (HP, stamina, XP).
struct LeanBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Lean(amount: height * 0.6).fill(.white.opacity(0.08))
                Lean(amount: height * 0.6).fill(color)
                    .frame(width: max(0, g.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
    }
}

/// A friend's photo (or art) in a hexagon, with an optional ring.
struct HexPortrait: View {
    let portrait: BattlePortrait
    let color: Color
    let monogram: String
    let width: CGFloat
    var ring: Color? = nil
    var artScale: CGFloat = 0.62

    var body: some View {
        let h = width * 1.1
        ZStack {
            if let ring {
                Hexagon().fill(ring)
                    .frame(width: width, height: h)
            }
            PortraitFill(portrait: portrait, color: color, monogram: monogram, artScale: artScale)
                .frame(width: ring == nil ? width : width - 10, height: ring == nil ? h : h - 11)
                .clipShape(Hexagon())
        }
        .frame(width: width, height: h)
    }
}
