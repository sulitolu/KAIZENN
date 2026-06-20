import SwiftUI

/// App settings — language, units, notifications, data, about.
/// Preferences persist via @AppStorage. Deeper behavior (full localization, unit
/// conversion across every screen) is wired incrementally; the toggles here are the
/// single home for those choices.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app_language")          private var language = "en"
    @AppStorage("weight_units")          private var weightUnits = "kg"
    @AppStorage("food_units")            private var foodUnits = "g"
    @AppStorage("notifications_enabled") private var notificationsEnabled = true

    @State private var showResetAlert = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {
                    header

                    section("LANGUAGE") {
                        segmentedRow(
                            options: [("en", "English"), ("ja", "日本語")],
                            selection: $language
                        )
                        Text("Full in-app translation is rolling out — your choice is saved now.")
                            .font(.system(size: 11))
                            .foregroundColor(KTheme.Colors.textTertiary)
                    }

                    section("UNITS") {
                        labeledRow("Body weight") {
                            segmentedRow(options: [("kg", "kg"), ("lb", "lb")], selection: $weightUnits)
                        }
                        labeledRow("Food") {
                            segmentedRow(options: [("g", "grams"), ("oz", "oz")], selection: $foodUnits)
                        }
                    }

                    section("NOTIFICATIONS") {
                        Toggle(isOn: $notificationsEnabled) {
                            Text("Reminders & nudges")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                        .tint(KTheme.Colors.accentPrimary)
                    }

                    section("DATA") {
                        Button { showResetAlert = true } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Reset all data")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            .foregroundColor(KTheme.Colors.accentSecondary)
                        }
                    }

                    section("ABOUT") {
                        HStack {
                            Text("Version")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Spacer()
                            Text(appVersion)
                                .font(.system(size: 15))
                                .foregroundColor(KTheme.Colors.textTertiary)
                        }
                        HStack {
                            Text("KAIZENN")
                                .font(.system(size: 13))
                                .foregroundColor(KTheme.Colors.textTertiary)
                            Spacer()
                        }
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .alert("Reset all data?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently clears your logged meals, water, weight, habits, tasks, and workouts on this device.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.accentPrimary)
                .tracking(1.5)
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                content()
            }
            .padding(KTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KTheme.Colors.cardElevated, lineWidth: 0.5)
                    )
            )
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ label: String, @ViewBuilder _ trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            trailing()
        }
    }

    private func segmentedRow(options: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { value, label in
                let selected = selection.wrappedValue == value
                Button { selection.wrappedValue = value } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selected ? .white : KTheme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected ? KTheme.Colors.accentPrimary : KTheme.Colors.cardElevated)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Reset

    private func resetAllData() {
        let keys = [
            "kaizenn_nutrition_entries",
            "kaizenn_water_entries",
            "kaizenn_weight_measurements",
            "kaizenn_habits",
            "kaizenn_tasks",
            "kaizenn_workouts",
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
