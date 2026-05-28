import SwiftUI

/// Shared color palette matching the OpenClaw web dashboard design system.
/// OpenClaw brand: claw-orange (#f97316) with deep dark backgrounds for native iOS context.
enum OpenClawTheme {
    // MARK: - Brand

    static let primary = Color(hex: "f97316")       // claw-orange brand color
    static let primaryHover = Color(hex: "fb923c")
    static let accent = Color(hex: "14b8a6")        // teal accent

    // MARK: - App Identity

    static let appName = "OpenClaw"
    static let appVersion = "Phase 1"

    // MARK: - Backgrounds (dark mode)

    static let background = Color(hex: "0e1015")    // deep dark
    static let surface = Color(hex: "161920")       // card surface
    static let surfaceElevated = Color(hex: "191c24") // elevated

    // MARK: - Text

    static let textPrimary = Color(hex: "d4d4d8")   // slate-300
    static let textSecondary = Color(hex: "f4f4f5") // slate-50
    static let textMuted = Color(hex: "838387")     // muted

    // MARK: - Status

    static let success = Color(hex: "22c55e")       // green-500
    static let warning = Color(hex: "f59e0b")      // amber-500
    static let error = Color(hex: "ef4444")        // red-500
    static let info = Color(hex: "3b82f6")         // blue-500

    // MARK: - Border

    static let border = Color(hex: "1e2028")        // whisper-thin
    static let borderLight = Color(hex: "2e3040")  // border-strong

    // MARK: - Chat bubbles

    static let userBubble = Color(hex: "f97316").opacity(0.15)
    static let agentBubble = Color(hex: "161920")

    // MARK: - Shadows

    static let shadowSm = Color(hex: "000000").opacity(0.25)
    static let shadowMd = Color(hex: "000000").opacity(0.3)
    static let shadowLg = Color(hex: "000000").opacity(0.4)

    // MARK: - Gradient

    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "f97316"), Color(hex: "ea580c")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

    /// Returns an orange-tinted tint color for interactive elements.
    static func tinted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primary : Color(hex: "ea580c")
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
