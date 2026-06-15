import SwiftUI

struct LogWorkoutView: View {
    @EnvironmentObject var activityStore: ActivityStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: WorkoutType
    @State private var duration: Double = 30
    @State private var calories: String = ""
    @State private var distanceKm: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()
    @State private var isLogging = false

    init(initialType: WorkoutType = .running) {
        _selectedType = State(initialValue: initialType)
    }

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {

                        // Workout type grid
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                                Text("Workout Type").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: KTheme.Spacing.sm) {
                                    ForEach(WorkoutType.allCases, id: \.self) { type in
                                        Button {
                                            selectedType = type
                                        } label: {
                                            VStack(spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                                                        .fill(selectedType == type ? KTheme.Colors.accentPrimary : KTheme.Colors.border.opacity(0.5))
                                                        .frame(width: 48, height: 48)
                                                    Image(systemName: type.icon)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(selectedType == type ? .white : KTheme.Colors.textSecondary)
                                                }
                                                Text(type.displayName)
                                                    .font(KTheme.Typography.caption)
                                                    .foregroundColor(selectedType == type ? KTheme.Colors.accentPrimary : KTheme.Colors.textTertiary)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Duration slider
                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                                HStack {
                                    Text("Duration").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(Int(duration)) min")
                                        .font(KTheme.Typography.headingMedium)
                                        .foregroundColor(KTheme.Colors.accentPrimary)
                                }
                                Slider(value: $duration, in: 5...180, step: 5)
                                    .tint(KTheme.Colors.accentPrimary)
                            }
                        }

                        // Stats
                        HStack(spacing: KTheme.Spacing.sm) {
                            KTextField(placeholder: "Calories burned", text: $calories, keyboardType: .numberPad, icon: "flame.fill")
                            KTextField(placeholder: "Distance (km)", text: $distanceKm, keyboardType: .decimalPad, icon: "mappin.and.ellipse")
                        }

                        // Date
                        KCard {
                            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .colorScheme(.dark)
                                .font(KTheme.Typography.bodyMedium)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }

                        // Notes
                        KTextField(placeholder: "Notes (optional)...", text: $notes, icon: "note.text")

                        // Log button
                        KButton(title: "Save Workout", isLoading: isLogging) {
                            logWorkout()
                        }
                        .padding(.bottom, KTheme.Spacing.xxl)
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func logWorkout() {
        isLogging = true
        let end = date.addingTimeInterval(duration * 60)
        var workout = WorkoutSession(startDate: date, type: selectedType)
        workout.endDate = end
        workout.caloriesBurned = Double(calories) ?? estimatedCalories()
        workout.distanceMeters = Double(distanceKm).map { $0 * 1000 }
        workout.notes = notes.isEmpty ? nil : notes
        workout.source = .manual
        activityStore.addWorkout(workout)
        Task { await healthKitManager.saveWorkout(workout) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLogging = false
            dismiss()
        }
    }

    private func estimatedCalories() -> Double {
        // Simple MET-based estimate (MET * weight * hours)
        let mets: [WorkoutType: Double] = [
            .running: 9.8, .walking: 3.5, .cycling: 8.0, .swimming: 8.0,
            .weightTraining: 5.0, .yoga: 3.0, .hiit: 10.0, .boxing: 9.0
        ]
        let met = mets[selectedType] ?? 6.0
        let weightKg = weightStore.latestWeight ?? appState.userProfile.currentWeightKg
        return met * weightKg * (duration / 60)
    }
}
