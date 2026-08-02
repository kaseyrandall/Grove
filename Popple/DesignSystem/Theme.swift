import SwiftUI

/// Popple's soft, playful visual language. Pastel-forward, rounded, gentle.
/// Tweak these and the whole app re-skins.
enum Theme {
    // MARK: Palette (soft pastels)
    static let blush    = Color(hex: 0xFFB3C7) // warm pink
    static let lavender = Color(hex: 0xC9B6FF) // dreamy purple
    static let mint     = Color(hex: 0x9FE8C8) // fresh green
    static let sky      = Color(hex: 0xA9D8FF) // soft blue
    static let gold     = Color(hex: 0xFFD98A) // sunny legendary glow
    static let cream    = Color(hex: 0xFFF7EF) // background
    static let ink      = Color(hex: 0x4A4458) // friendly dark text

    /// Primary brand accent (buttons, tint).
    static let accent   = Color(hex: 0xFF7EA6)

    /// The app's default background — a soft vertical wash.
    static var background: LinearGradient {
        LinearGradient(
            colors: [cream, sky.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Type
    static func title(_ text: String) -> Text {
        Text(text).font(.system(.title, design: .rounded, weight: .bold))
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Reusable soft card styling
struct SoftCard: ViewModifier {
    var fill: Color = .white
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: Theme.ink.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Wraps content in Popple's signature soft, rounded card.
    func softCard(fill: Color = .white) -> some View {
        modifier(SoftCard(fill: fill))
    }
}
