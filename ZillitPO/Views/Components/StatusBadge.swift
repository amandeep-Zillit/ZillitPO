import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - StatusBadge
//
// SwiftUI mirror of the web's `StatusBadge` component:
//
//     <StatusBadge color="green">Approved</StatusBadge>
//
// Reusable, colored, borderless chip with bold mono text. Each named
// colour maps to a solid foreground + translucent (15 % alpha)
// background — same derivation the web uses via Tailwind's `/15`
// opacity suffix. Keeps invoice / PO / card status pills consistent
// across every list, row, and detail page.
//
// Usage (Swift):
//
//     StatusBadge("Approved",             color: .green)
//     StatusBadge("Pending (2/3)",        color: .amber)
//     StatusBadge("Urgent Wire Request",  color: .pink)
//
// Initialisers accept both a String and a Text view so callers can
// interpolate counts / dynamic values without building an extra
// `Text` wrapper at the call site.
// ═══════════════════════════════════════════════════════════════════

/// Named colour palette — one case per slot in the web's COLOR_MAP.
/// The hex literals for `amber` / `pink` match the web's brand tokens
/// (`#fc9404` / `#e84b7a`) so iOS and browser renderings are visually
/// identical. The rest lean on SwiftUI's built-in semantic colours.
enum StatusBadgeColor {
    case green
    case red
    case amber
    case blue
    case gray
    case pink
    case teal
    case purple

    /// Text colour for the badge. Matches the web's `text-{color}-600`
    /// Tailwind class (or the custom brand hex for amber / pink).
    var foreground: Color {
        switch self {
        case .green:  return Color(red: 0.14, green: 0.55, blue: 0.26)      // text-green-600
        case .red:    return Color(red: 0.86, green: 0.15, blue: 0.15)      // text-red-600
        case .amber:  return Color(red: 0.878, green: 0.525, blue: 0.0)     // #e08600
        case .blue:   return Color(red: 0.15, green: 0.39, blue: 0.92)      // text-blue-600
        case .gray:   return Color(red: 0.42, green: 0.45, blue: 0.5)       // text-gray-500
        case .pink:   return Color(red: 0.91, green: 0.294, blue: 0.478)    // #e84b7a
        case .teal:   return Color(red: 0.051, green: 0.584, blue: 0.565)   // text-teal-600
        case .purple: return Color(red: 0.482, green: 0.227, blue: 0.929)   // text-purple-600
        }
    }

    /// Tinted 15 % background. Web uses `bg-{color}/15`; `.gray` is
    /// the only exception — it uses a solid `bg-gray-100` to stay
    /// readable against light backgrounds.
    var background: Color {
        switch self {
        case .gray: return Color(red: 0.95, green: 0.96, blue: 0.97)        // bg-gray-100
        default:    return foreground.opacity(0.15)
        }
    }
}

/// Reusable status chip — small, bold, monospaced text with a tinted
/// pill behind it. Drop-in for every "status" UI surface in the app.
struct StatusBadge: View {
    private let text: String
    private let color: StatusBadgeColor

    init(_ text: String, color: StatusBadgeColor = .gray) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(color.foreground)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.background)
            .cornerRadius(6)
            .fixedSize(horizontal: true, vertical: false)
    }
}
