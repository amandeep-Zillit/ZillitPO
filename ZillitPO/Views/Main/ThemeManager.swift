//
//  ThemeManager.swift
//  ZillitPO
//

import SwiftUI

// MARK: - Theme Manager (singleton, drives all Color.xxx tokens)

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "app-theme-dark") }
    }

    private init() {
        self.isDark = UserDefaults.standard.bool(forKey: "app-theme-dark")
    }

    func toggleTheme() { isDark.toggle() }

    // ── Brand colors (matching web ThemeContext.jsx) ──────────────

    var primary: Color {                                             // gold
        Color(red: 252/255, green: 148/255, blue: 4/255)            // #FC9404
    }

    var primaryDark: Color {                                         // goldDark
        Color(red: 224/255, green: 134/255, blue: 0/255)            // #E08600
    }

    // ── Full palette (light / dark from ThemeContext.jsx) ─────────

    var bgBase: Color {          // --bg-base
        isDark ? Color(hex: "#14161B") : Color(hex: "#F8F9FB")
    }

    var bgSurface: Color {       // --bg-surface  (cards, rows)
        isDark ? Color(hex: "#1A1D23") : Color.white
    }

    var bgRaised: Color {        // --bg-raised
        isDark ? Color(hex: "#22262E") : Color(hex: "#F3F4F6")
    }

    var borderColor: Color {     // --border
        isDark ? Color.white.opacity(0.08) : Color(hex: "#E2E4E9")
    }

    var borderSubtle: Color {    // --border-subtle
        isDark ? Color(hex: "#2A2E38") : Color(hex: "#EDF0F4")
    }

    var textPrimary: Color {     // --text
        isDark ? Color(hex: "#E5E7EB") : Color(UIColor.label)
    }

    var textSecondary: Color {   // --text-dim
        isDark ? Color(hex: "#9CA3AF") : Color(UIColor.secondaryLabel)
    }

    var textMuted: Color {       // --text-muted
        isDark ? Color(hex: "#6B7280") : Color(UIColor.tertiaryLabel)
    }
}

// MARK: - Color(hex:) initialiser

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 6: // RGB
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (252, 148, 4, 255) // fallback to gold
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

// MARK: - Theme-aware Color tokens

extension Color {
    static var gold: Color       {
        ThemeManager.shared.primary
    }
    static var goldDark: Color   { ThemeManager.shared.primaryDark }
    static var bgBase: Color     { ThemeManager.shared.bgBase }
    static var bgRaised: Color   { ThemeManager.shared.bgRaised }
    static var bgSurface: Color  { ThemeManager.shared.bgSurface }
    static var borderColor: Color { ThemeManager.shared.borderColor }
    static var borderSubtle: Color { ThemeManager.shared.borderSubtle }
}
