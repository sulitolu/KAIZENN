import SwiftUI

struct SportProfileSetupView: View {
    @Binding var sportProfile: SportProfile
    let onNext: () -> Void

    @State private var step = 0

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sub-step progress dots
                HStack(spacing: 6) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i <= step ? KTheme.Colors.accentPrimary : KTheme.Colors.border)
                            .frame(width: 6, height: 6)
                            .animation(KTheme.Animation.snappy, value: step)
                    }
                }
                .padding(.top, KTheme.Spacing.lg)
                .padding(.bottom, KTheme.Spacing.md)

                // Step content
                Group {
                    switch step {
                    case 0: sportStep
                    case 1: positionStep
                    case 2: phaseStep
                    case 3: dayStep
                    default: wearableStep
                    }
                }
            }
        }
    }

    // MARK: Step 0 — Sport Selection
    private var sportStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(
                step: "1 / 5",
                title: "Your Sport",
                subtitle: "Select your primary sport for personalised targets"
            )

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: KTheme.Spacing.sm) {
                ForEach(SportProfile.Sport.allCases, id: \.self) { sport in
                    let isSelected = sportProfile.sport == sport
                    Button {
                        withAnimation(KTheme.Animation.snappy) {
                            sportProfile.sport = sport
                        }
                    } label: {
                        VStack(spacing: KTheme.Spacing.xs) {
                            Image(systemName: sportIcon(sport))
                                .font(.system(size: 28))
                                .foregroundColor(selectionTextColor(isSelected: isSelected, selectedColor: .black, deselectedColor: .white))
                            Text(sport.displayName)
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(selectionTextColor(isSelected: isSelected, selectedColor: .black, deselectedColor: KTheme.Colors.textPrimary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KTheme.Spacing.lg)
                        .background(selectionCellBackground(isSelected: isSelected, radius: KTheme.Radius.md))
                    }
                    .buttonStyle(KScaleButtonStyle())
                }
            }

            Spacer()
            continueButton(title: "Continue", enabled: true) {
                withAnimation(KTheme.Animation.smooth) { step = 1 }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 1 — Position
    private var positionStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(
                step: "2 / 5",
                title: "Your Position",
                subtitle: "Select your position in \(sportProfile.sport.displayName)"
            )

            ScrollView {
                VStack(spacing: KTheme.Spacing.xs) {
                    ForEach(sportProfile.sport.positions, id: \.self) { pos in
                        let isSelected = sportProfile.position == pos
                        Button {
                            withAnimation(KTheme.Animation.snappy) {
                                sportProfile.position = pos
                            }
                        } label: {
                            HStack {
                                Text(pos)
                                    .font(KTheme.Typography.bodyMedium)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(KTheme.Colors.accentPrimary)
                                }
                            }
                            .padding(KTheme.Spacing.md)
                            .background(accentCellBackground(isSelected: isSelected, fillOpacity: 0.12, radius: KTheme.Radius.md))
                        }
                    }
                }
            }

            HStack {
                backButton
                continueButton(title: "Continue", enabled: !sportProfile.position.isEmpty) {
                    withAnimation(KTheme.Animation.smooth) { step = 2 }
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
        .onAppear {
            // Default to first position when sport changes
            if sportProfile.position.isEmpty || !sportProfile.sport.positions.contains(sportProfile.position) {
                sportProfile.position = sportProfile.sport.positions.first ?? ""
            }
        }
    }

    // MARK: Step 2 — Season Phase
    private var phaseStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(
                step: "3 / 5",
                title: "Season Phase",
                subtitle: "Your current training phase affects nutrition targets"
            )

            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(SportProfile.SeasonPhase.allCases, id: \.self) { phase in
                    let isSelected = sportProfile.seasonPhase == phase
                    Button {
                        withAnimation(KTheme.Animation.snappy) {
                            sportProfile.seasonPhase = phase
                        }
                    } label: {
                        HStack(spacing: KTheme.Spacing.md) {
                            Image(systemName: phaseIcon(phase))
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? KTheme.Colors.accentPrimary : KTheme.Colors.textSecondary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phase.displayName)
                                    .font(KTheme.Typography.headingSmall)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                Text(phaseDescription(phase))
                                    .font(KTheme.Typography.caption)
                                    .foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(KTheme.Colors.accentPrimary)
                            }
                        }
                        .padding(KTheme.Spacing.md)
                        .background(accentCellBackground(isSelected: isSelected, fillOpacity: 0.1, radius: KTheme.Radius.md))
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                continueButton(title: "Continue", enabled: true) {
                    withAnimation(KTheme.Animation.smooth) { step = 3 }
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 3 — Performance Day
    private var dayStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(
                step: "4 / 5",
                title: "Game Day",
                subtitle: "When is your main performance or match day?"
            )

            KCard {
                VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                    Text("Day of Week")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    HStack(spacing: KTheme.Spacing.xs) {
                        ForEach(0..<7) { i in
                            // weekday: Sun=1, Mon=2 ... Sat=7
                            let weekday = i + 1
                            let isSelected = sportProfile.performanceDayOfWeek == weekday
                            Button {
                                withAnimation(KTheme.Animation.snappy) {
                                    sportProfile.performanceDayOfWeek = weekday
                                }
                            } label: {
                                Text(dayLabels[i])
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(selectionTextColor(isSelected: isSelected, selectedColor: .black, deselectedColor: KTheme.Colors.textSecondary))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectionCellBackground(isSelected: isSelected, radius: KTheme.Radius.sm))
                            }
                        }
                    }

                    let daysAway = sportProfile.daysUntilPerformance
                    Text(daysAway == 0
                        ? "Performance day is today"
                        : "Performance day is in \(daysAway) day\(daysAway == 1 ? "" : "s")")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
            }

            Spacer()
            HStack {
                backButton
                continueButton(title: "Continue", enabled: true) {
                    withAnimation(KTheme.Animation.smooth) { step = 4 }
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 4 — Wearable
    private var wearableStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(
                step: "5 / 5",
                title: "Your Wearable",
                subtitle: "Connect your device for training load data"
            )

            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(SportProfile.Wearable.allCases, id: \.self) { device in
                    let isSelected = sportProfile.wearable == device
                    Button {
                        withAnimation(KTheme.Animation.snappy) {
                            sportProfile.wearable = device
                        }
                    } label: {
                        HStack(spacing: KTheme.Spacing.md) {
                            Image(systemName: wearableIcon(device))
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? KTheme.Colors.accentPrimary : KTheme.Colors.textSecondary)
                                .frame(width: 32)
                            Text(device.displayName)
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(KTheme.Colors.accentPrimary)
                            }
                        }
                        .padding(KTheme.Spacing.md)
                        .background(accentCellBackground(isSelected: isSelected, fillOpacity: 0.1, radius: KTheme.Radius.md))
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                KButton(title: "Start My Journey") {
                    onNext()
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Selection Cell Styling Helpers

    /// Standard selection cell: accent fill vs dark fill, clear vs border stroke.
    /// Used by sport grid and day-of-week picker.
    private func selectionCellBackground(isSelected: Bool, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(isSelected ? KTheme.Colors.accentPrimary : Color(hex: "1A1A28"))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isSelected ? Color.clear : KTheme.Colors.border, lineWidth: 0.5)
            )
    }

    /// Accent-tinted selection cell: accent.opacity vs card fill, accent vs border.opacity stroke.
    /// Used by position, phase, and wearable pickers.
    private func accentCellBackground(isSelected: Bool, fillOpacity: Double, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(isSelected ? KTheme.Colors.accentPrimary.opacity(fillOpacity) : KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isSelected ? KTheme.Colors.accentPrimary : KTheme.Colors.border.opacity(0.4), lineWidth: 1)
            )
    }

    /// Returns a foreground color based on selection state.
    private func selectionTextColor(isSelected: Bool, selectedColor: Color, deselectedColor: Color) -> Color {
        isSelected ? selectedColor : deselectedColor
    }

    // MARK: Shared Helpers
    private func stepHeader(step: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
            Text(step)
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)
                .padding(.top, KTheme.Spacing.lg)
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backButton: some View {
        Button {
            withAnimation(KTheme.Animation.smooth) { step -= 1 }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KTheme.Colors.textSecondary)
                .frame(width: 50, height: 50)
                .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
        }
    }

    private func continueButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        KButton(title: title, style: .primary) {
            action()
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    // MARK: Icon Helpers
    private func sportIcon(_ sport: SportProfile.Sport) -> String {
        switch sport {
        case .rugby:      return "oval.fill"
        case .soccer:     return "soccerball"
        case .basketball: return "basketball.fill"
        case .athletics:  return "figure.run"
        case .gym:        return "dumbbell.fill"
        case .swimming:   return "figure.pool.swim"
        case .cycling:    return "bicycle"
        case .other:      return "sportscourt.fill"
        }
    }

    private func phaseIcon(_ phase: SportProfile.SeasonPhase) -> String {
        switch phase {
        case .preSeason: return "bolt.fill"
        case .inSeason:  return "star.fill"
        case .offSeason: return "moon.fill"
        }
    }

    private func phaseDescription(_ phase: SportProfile.SeasonPhase) -> String {
        switch phase {
        case .preSeason: return "Building base fitness and strength"
        case .inSeason:  return "Competing — maintain performance"
        case .offSeason: return "Recovery and off-training period"
        }
    }

    private func wearableIcon(_ device: SportProfile.Wearable) -> String {
        switch device {
        case .whoop:      return "waveform.path.ecg"
        case .garmin:     return "mappin.circle.fill"
        case .polar:      return "heart.circle.fill"
        case .appleWatch: return "applewatch"
        case .none:       return "xmark.circle"
        }
    }
}
