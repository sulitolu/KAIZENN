import SwiftUI

/// App settings — language, units, notifications, data, about.
/// Preferences persist via @AppStorage. Deeper behavior (full localization, unit
/// conversion across every screen) is wired incrementally; the toggles here are the
/// single home for those choices.
///
/// "Reset all data" is deliberately defended: it lives behind a collapsed Advanced
/// disclosure and requires typing RESET to confirm, so it can't be triggered by a
/// stray tap.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("app_language")          private var language = "en"
    @AppStorage("weight_units")          private var weightUnits = "kg"
    @AppStorage("food_units")            private var foodUnits = "g"
    @AppStorage("notifications_enabled") private var notificationsEnabled = false

    @State private var showAdvanced = false
    @State private var showResetSheet = false
    @State private var resetConfirmText = ""
    @State private var notificationsDenied = false

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

                    section(L.t("settings.section.language", language), icon: "globe") {
                        segmentedRow(
                            options: [("en", "English"), ("ja", "日本語")],
                            selection: $language
                        )
                        Text(L.t("settings.language.note", language))
                            .font(.system(size: 11))
                            .foregroundColor(KTheme.Colors.textTertiary)
                    }

                    section(L.t("settings.section.units", language), icon: "ruler") {
                        labeledRow(L.t("settings.units.bodyWeight", language)) {
                            segmentedRow(options: [("kg", "kg"), ("lb", "lb")], selection: $weightUnits)
                        }
                        labeledRow(L.t("settings.units.food", language)) {
                            segmentedRow(options: [("g", "grams"), ("oz", "oz")], selection: $foodUnits)
                        }
                    }

                    section(L.t("settings.section.notifications", language), icon: "bell.fill") {
                        Toggle(isOn: $notificationsEnabled) {
                            HStack(spacing: KTheme.Spacing.sm) {
                                iconTile("bell.badge.fill", KTheme.Colors.accentPrimary)
                                Text(L.t("settings.notifications.reminders", language))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(KTheme.Colors.textPrimary)
                            }
                        }
                        .tint(KTheme.Colors.accentPrimary)
                        .onChange(of: notificationsEnabled) { _, isOn in
                            handleNotificationsToggle(isOn)
                        }
                        if notificationsDenied {
                            Text(L.t("settings.notifications.denied", language))
                                .font(.system(size: 11))
                                .foregroundColor(KTheme.Colors.textTertiary)
                        }
                    }

                    section(L.t("settings.section.data", language), icon: "externaldrive.fill") {
                        advancedDisclosure
                    }

                    section(L.t("settings.section.about", language), icon: "info.circle.fill") {
                        HStack(spacing: KTheme.Spacing.sm) {
                            iconTile("number", KTheme.Colors.textSecondary)
                            Text(L.t("settings.about.version", language))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Spacer()
                            Text(appVersion)
                                .font(.system(size: 15))
                                .foregroundColor(KTheme.Colors.textTertiary)
                        }
                    }

                    aboutFooter

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showResetSheet, onDismiss: { resetConfirmText = "" }) {
            resetConfirmSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(L.t("settings.title", language))
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Button(L.t("common.done", language)) { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    // MARK: - Advanced / Reset (defended)

    private var advancedDisclosure: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
            Button {
                withAnimation(KTheme.Animation.snappy) { showAdvanced.toggle() }
            } label: {
                HStack(spacing: KTheme.Spacing.sm) {
                    iconTile("wrench.and.screwdriver.fill", KTheme.Colors.textSecondary)
                    Text(L.t("settings.data.advanced", language))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showAdvanced {
                Button { showResetSheet = true } label: {
                    HStack(spacing: KTheme.Spacing.sm) {
                        iconTile("exclamationmark.triangle.fill", KTheme.Colors.accentSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("settings.data.resetAll", language))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(KTheme.Colors.accentSecondary)
                            Text(L.t("settings.data.resetSubtitle", language))
                                .font(.system(size: 11))
                                .foregroundColor(KTheme.Colors.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(KTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KTheme.Colors.accentSecondary.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var resetMatches: Bool {
        resetConfirmText.trimmingCharacters(in: .whitespaces).uppercased() == "RESET"
    }

    private var resetConfirmSheet: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: KTheme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(KTheme.Colors.accentSecondary.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(KTheme.Colors.accentSecondary)
                }
                .padding(.top, KTheme.Spacing.xl)

                VStack(spacing: KTheme.Spacing.sm) {
                    Text(L.t("settings.reset.title", language))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text(L.t("settings.reset.body", language))
                        .font(.system(size: 14))
                        .foregroundColor(KTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, KTheme.Spacing.md)
                }

                VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                    Text(L.t("settings.reset.typeToConfirm", language))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .tracking(1.5)
                    TextField("", text: $resetConfirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(KTheme.Colors.textPrimary)
                        .padding(KTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(KTheme.Colors.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(resetMatches ? KTheme.Colors.accentSecondary : KTheme.Colors.cardElevated, lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, KTheme.Spacing.md)

                Spacer()

                VStack(spacing: KTheme.Spacing.sm) {
                    Button {
                        resetAllData()
                        showResetSheet = false
                        dismiss()
                    } label: {
                        Text(L.t("settings.reset.confirmButton", language))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(resetMatches ? KTheme.Colors.accentSecondary : KTheme.Colors.cardElevated)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!resetMatches)

                    Button(L.t("common.cancel", language)) { showResetSheet = false }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KTheme.Colors.textSecondary)
                        .padding(.vertical, 6)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.bottom, KTheme.Spacing.xl)
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Footer

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("KAIZENN")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(KTheme.Colors.textSecondary)
                .tracking(2)
            Text("Marginal gains, every day.")
                .font(.system(size: 11))
                .foregroundColor(KTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, KTheme.Spacing.md)
    }

    // MARK: - Building blocks

    private func iconTile(_ symbol: String, _ tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.18))
                .frame(width: 30, height: 30)
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(KTheme.Colors.accentPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.accentPrimary)
                    .tracking(1.5)
            }
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

    // MARK: - Notifications

    private func handleNotificationsToggle(_ isOn: Bool) {
        if isOn {
            Task {
                let granted = await NotificationManager.shared.requestAuthorization()
                if granted {
                    notificationsDenied = false
                    NotificationManager.shared.scheduleDailyReminders()
                } else {
                    notificationsDenied = true
                    notificationsEnabled = false
                }
            }
        } else {
            notificationsDenied = false
            Task { NotificationManager.shared.cancelAll() }
        }
    }

    // MARK: - Reset

    private func resetAllData() {
        // Every logged-data key the stores persist under. Intentionally keeps
        // "kaizenn_user_profile" so the user isn't bounced back into onboarding.
        let keys = [
            // Nutrition
            "kaizenn_nutrition_entries",
            "kaizenn_meal_entries",
            "kaizenn_custom_foods",
            "kaizenn_fav_foods",
            // Hydration
            "kaizenn_water_entries",
            // Body
            "kaizenn_weight_measurements",
            // Training / load
            "kaizenn_workouts",
            "kaizenn_strength_sessions",
            "kaizenn_gps_sessions",
            "kaizenn_daily_activities",
            // Planning
            "kaizenn_habits",
            "kaizenn_tasks",
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
