import SwiftUI

// MARK: — KAIZENN Design System
// Premium dark theme with violet-to-coral gradient identity

enum KTheme {

    // MARK: Colors
    enum Colors {
        // Near-black depth layers — matched to the approved premium mockup
        static let background       = Color(hex: "080810")  // pure near-black screen bg
        static let surface          = Color(hex: "0F0F1E")
        static let card             = Color(hex: "0C0C16")  // near-black floating card
        static let cardElevated     = Color(hex: "1A1A28")  // lighter surface / unselected
        static let border           = Color(hex: "3A3A5A")  // visible bluish hairline

        static let accentPrimary    = Color(hex: "7C6FFF")  // Electric violet
        static let accentSecondary  = Color(hex: "FF6B8A")  // Coral pink
        static let accentTertiary   = Color(hex: "4ECDC4")  // Teal — GPS/load
        static let accentAmber      = Color(hex: "FFB347")  // Warm amber — nutrition
        static let accentGreen      = Color(hex: "5EFFB7")  // Peak / optimal / connected

        static let textPrimary      = Color(hex: "E8E8F0")
        static let textSecondary    = Color(hex: "8888A8")
        static let textTertiary     = Color(hex: "6B6B8A")

        static let success          = Color(hex: "5EFFB7")  // green for optimal states
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
            colors: [Color(hex: "0F0F1E"), Color(hex: "080810")],
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

// MARK: — In-app Localization (L)
// Lightweight key → [lang → String] lookup with English fallback. Views read
// @AppStorage("app_language") in their body and render strings via L.t(key, lang);
// reading the AppStorage in-body is what makes the language switch live (no restart).
// New file creation is intentionally avoided — this lives in an already-compiled file.
enum L {
    static func t(_ key: String, _ lang: String) -> String {
        table[key]?[lang] ?? table[key]?["en"] ?? key
    }

    private static let table: [String: [String: String]] = [
        // Tab bar
        "tab.home":      ["en": "Home",     "ja": "ホーム"],
        "tab.fuel":      ["en": "Fuel",     "ja": "栄養"],
        "tab.hub":       ["en": "Hub",      "ja": "ハブ"],
        "tab.kai":       ["en": "Kai",      "ja": "カイ"],
        "tab.schedule":  ["en": "Schedule", "ja": "スケジュール"],

        // Settings — header & buttons
        "settings.title":        ["en": "Settings", "ja": "設定"],
        "common.done":           ["en": "Done",     "ja": "完了"],
        "common.cancel":         ["en": "Cancel",   "ja": "キャンセル"],

        // Settings — section headers
        "settings.section.language":      ["en": "LANGUAGE",      "ja": "言語"],
        "settings.section.units":         ["en": "UNITS",         "ja": "単位"],
        "settings.section.notifications": ["en": "NOTIFICATIONS", "ja": "通知"],
        "settings.section.data":          ["en": "DATA",          "ja": "データ"],
        "settings.section.about":         ["en": "ABOUT",         "ja": "アプリについて"],

        // Settings — language note
        "settings.language.note": [
            "en": "Full in-app translation is rolling out — your choice is saved now.",
            "ja": "アプリ全体の翻訳は順次対応中です。選択は今すぐ保存されます。",
        ],

        // Settings — units rows
        "settings.units.bodyWeight": ["en": "Body weight", "ja": "体重"],
        "settings.units.food":       ["en": "Food",        "ja": "食事"],

        // Settings — notifications
        "settings.notifications.reminders": ["en": "Reminders & nudges", "ja": "リマインダーと通知"],
        "settings.notifications.denied": [
            "en": "Notifications are turned off in iOS Settings. Enable them for KAIZENN to receive reminders.",
            "ja": "通知はiOSの設定でオフになっています。リマインダーを受け取るにはKAIZENNの通知を有効にしてください。",
        ],

        // Settings — data / advanced / reset
        "settings.data.advanced":     ["en": "Advanced",      "ja": "詳細設定"],
        "settings.data.resetAll":     ["en": "Reset all data", "ja": "すべてのデータをリセット"],
        "settings.data.resetSubtitle": [
            "en": "Clears everything on this device",
            "ja": "この端末のすべてのデータを消去します",
        ],

        // Settings — reset confirmation sheet
        "settings.reset.title": ["en": "Reset all data", "ja": "すべてのデータをリセット"],
        "settings.reset.body": [
            "en": "This permanently clears your logged meals, water, weight, habits, tasks, and workouts on this device. This cannot be undone.",
            "ja": "この端末に記録された食事・水分・体重・習慣・タスク・ワークアウトを完全に消去します。この操作は取り消せません。",
        ],
        "settings.reset.typeToConfirm": [
            "en": "Type RESET to confirm",
            "ja": "確認のため RESET と入力してください",
        ],
        "settings.reset.confirmButton": ["en": "Reset everything", "ja": "すべてリセット"],

        // Settings — about
        "settings.about.version": ["en": "Version", "ja": "バージョン"],

        // Dashboard header
        "dashboard.athlete":          ["en": "Athlete",   "ja": "アスリート"],
        "dashboard.readiness":        ["en": "READINESS",      "ja": "コンディション"],
        "dashboard.readiness.peak":   ["en": "PEAK CONDITION", "ja": "最高のコンディション"],
        "dashboard.readiness.gameReady": ["en": "GAME READY",  "ja": "試合準備完了"],
        "dashboard.readiness.build":  ["en": "BUILD DAY",      "ja": "強化日"],
        "dashboard.readiness.recovery": ["en": "RECOVERY DAY", "ja": "回復日"],
        "readiness.primed":   ["en": "PRIMED",   "ja": "絶好調"],
        "readiness.ready":    ["en": "READY",    "ja": "良好"],
        "readiness.moderate": ["en": "MODERATE", "ja": "普通"],
        "readiness.caution":  ["en": "CAUTION",  "ja": "注意"],
        "readiness.recover":  ["en": "RECOVER",  "ja": "回復優先"],
        "dashboard.edge.sleep": [
            "en": "Your edge: target 8hrs sleep tonight.",
            "ja": "あなたの強み：今夜は8時間の睡眠を目指しましょう。",
        ],
        "dashboard.edge.fuel": [
            "en": "Your edge: hit protein target before training.",
            "ja": "あなたの強み：トレーニング前にタンパク質目標を達成しましょう。",
        ],
        "dashboard.edge.load": [
            "en": "Your edge: ease load — ACWR above sweet spot.",
            "ja": "あなたの強み：負荷を抑えましょう — ACWRが適正値を超えています。",
        ],
        "dashboard.edge.primed": [
            "en": "You are primed. Attack today's session.",
            "ja": "準備は万全です。今日のセッションに全力で挑みましょう。",
        ],
    ]
}
