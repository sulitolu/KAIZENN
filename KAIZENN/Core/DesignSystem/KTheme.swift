import SwiftUI

// MARK: — KAIZENN Design System
// Premium dark theme with violet-to-coral gradient identity

enum KTheme {

    // MARK: Colors
    enum Colors {
        static let background       = Color(hex: "0A0A0F")
        static let surface          = Color(hex: "12121A")
        static let card             = Color(hex: "1A1A26")
        static let cardElevated     = Color(hex: "20202E")
        static let border           = Color(hex: "2A2A3A")

        static let accentPrimary    = Color(hex: "7C6FFF")  // Electric violet
        static let accentSecondary  = Color(hex: "FF6B8A")  // Coral pink
        static let accentTertiary   = Color(hex: "4ECDC4")  // Teal
        static let accentAmber      = Color(hex: "FFB347")  // Warm amber

        static let textPrimary      = Color(hex: "F2F2FF")
        static let textSecondary    = Color(hex: "8888AA")
        static let textTertiary     = Color(hex: "55556A")

        static let success          = Color(hex: "4ECDC4")
        static let warning          = Color(hex: "FFB347")
        static let danger           = Color(hex: "FF6B8A")

        // Gradient presets
        static let brandGradient = LinearGradient(
            colors: [Color(hex: "7C6FFF"), Color(hex: "FF6B8A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let energyGradient = LinearGradient(
            colors: [Color(hex: "FF6B8A"), Color(hex: "FFB347")],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let calmGradient = LinearGradient(
            colors: [Color(hex: "4ECDC4"), Color(hex: "7C6FFF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let darkGradient = LinearGradient(
            colors: [Color(hex: "12121A"), Color(hex: "0A0A0F")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Typography
    enum Typography {
        static let displayLarge  = Font.system(size: 40, weight: .bold, design: .default)
        static let displayMedium = Font.system(size: 32, weight: .bold, design: .default)
        static let displaySmall  = Font.system(size: 24, weight: .bold, design: .default)
        static let headingLarge  = Font.system(size: 22, weight: .semibold, design: .default)
        static let headingMedium = Font.system(size: 18, weight: .semibold, design: .default)
        static let headingSmall  = Font.system(size: 16, weight: .semibold, design: .default)
        static let bodyLarge     = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium    = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall     = Font.system(size: 12, weight: .regular, design: .default)
        static let label         = Font.system(size: 13, weight: .medium, design: .default)
        static let caption       = Font.system(size: 11, weight: .medium, design: .default)
        static let mono          = Font.system(size: 14, weight: .medium, design: .monospaced)
    }

    // MARK: Spacing
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: Corner Radius
    enum Radius {
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 14
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: Animations
    enum Animation {
        static let spring    = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.75)
        static let snappy    = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let smooth    = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow      = SwiftUI.Animation.easeInOut(duration: 0.6)
        static let bounce    = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: — Color Hex Init
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
            (a, r, g, b) = (1, 1, 1, 0)
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
