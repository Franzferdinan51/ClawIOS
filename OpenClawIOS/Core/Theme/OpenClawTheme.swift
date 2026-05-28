import SwiftUI

/// Shared color palette matching the OpenClaw web dashboard design system.
/// Based on the claw-orange primary (#f97316) with dark slate backgrounds
/// for the native iOS context.
enum OpenClawTheme {
    // MARK: - Brand

    static let primary = Color(hex: "f97316")       // claw-orange
    static let primaryHover = Color(hex: "ea580c")
    static let accent = Color(hex: "fb923c")        // lighter orange

    // MARK: - Backgrounds

    static let background = Color(hex: "0f172a")    // slate-900 (dark mode base)
    static let surface = Color(hex: "1e293b")       // slate-800
    static let surfaceElevated = Color(hex: "334155") // slate-700

    // MARK: - Text

    static let textPrimary = Color(hex: "f8fafc")   // slate-50
    static let textSecondary = Color(hex: "94a3b8") // slate-400
    static let textMuted = Color(hex: "64748b")     // slate-500

    // MARK: - Status

    static let success = Color(hex: "22c55e")       // green-500
    static let warning = Color(hex: "eab308")      // yellow-500
    static let error = Color(hex: "ef4444")        // red-500
    static let info = Color(hex: "3b82f6")         // blue-500

    // MARK: - Border

    static let border = Color(hex: "334155")        // slate-700
    static let borderLight = Color(hex: "475569")  // slate-600

    // MARK: - Chat bubbles

    static let userBubble = Color(hex: "f97316").opacity(0.15)
    static let agentBubble = Color(hex: "1e293b")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Theme (supports light/dark system preference)

extension OpenClawTheme {
    /// Returns the appropriate card background based on color scheme.
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? surface : Color(hex: "f8fafc")
    }

    static func textColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? textPrimary : Color(hex: "0f172a")
    }

    /// Card padding matching the web dashboard's surface cards.
    static func cardPadding() -> EdgeInsets {
        EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    }

    /// Rounded card modifier with OpenClaw surface color.
    static func cardModifier() -> some ViewModifier {
        CardModifier()
    }
}

private struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(OpenClawTheme.cardPadding())
            .background(OpenClawTheme.cardBackground(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func openClawCard() -> some View {
        modifier(CardModifier())
    }
}