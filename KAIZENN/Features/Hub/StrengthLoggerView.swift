import SwiftUI

struct StrengthLoggerView: View {
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) private var dismiss

    @State private var exercises: [StrengthExercise] = []
    @State private var showPresetPicker = false
    @State private var customExerciseName = ""
    @State private var showCustomEntry = false
    @State private var saveError: String? = nil

    private var totalVolume: Double {
        exercises.flatMap(\.sets).reduce(0) { $0 + ($1.reps * $1.weightKg) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KTheme.Spacing.lg) {
                    volumeSummaryCard
                    exerciseList
                    addExerciseControls
                    if let error = saveError {
                        Text(error)
                            .font(KTheme.Typography.bodySmall)
                            .foregroundColor(KTheme.Colors.danger)
                            .padding(.horizontal)
                    }
                    KButton(title: "Save Session", style: .primary) {
                        saveSession()
                    }
                    .padding(.horizontal, KTheme.Spacing.md)
                }
                .padding(.vertical, KTheme.Spacing.md)
            }
            .background(KTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Log Strength Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
            .sheet(isPresented: $showPresetPicker) {
                presetPickerSheet
            }
        }
    }

    // MARK: Volume Summary

    private var volumeSummaryCard: some View {
        KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    Text("Total Volume")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                    Text(String(format: "%.0f kg", totalVolume))
                        .font(KTheme.Typography.displaySmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                }
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28))
                    .foregroundColor(KTheme.Colors.accentPrimary)
            }
        }
        .padding(.horizontal, KTheme.Spacing.md)
    }

    // MARK: Exercise List

    private var exerciseList: some View {
        VStack(spacing: KTheme.Spacing.md) {
            ForEach(exercises.indices, id: \.self) { idx in
                ExerciseCard(exercise: $exercises[idx]) {
                    exercises.remove(at: idx)
                }
                .padding(.horizontal, KTheme.Spacing.md)
            }
        }
    }

    // MARK: Add Exercise Controls

    private var addExerciseControls: some View {
        VStack(spacing: KTheme.Spacing.sm) {
            KButton(title: "Add Exercise from Presets", style: .secondary) {
                showPresetPicker = true
            }
            .padding(.horizontal, KTheme.Spacing.md)

            if showCustomEntry {
                HStack(spacing: KTheme.Spacing.sm) {
                    KTextField(placeholder: "Exercise name", text: $customExerciseName)
                    Button {
                        addCustomExercise()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(KTheme.Colors.accentPrimary)
                    }
                }
                .padding(.horizontal, KTheme.Spacing.md)
            } else {
                Button {
                    showCustomEntry = true
                } label: {
                    HStack(spacing: KTheme.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Custom Exercise")
                            .font(KTheme.Typography.label)
                    }
                    .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: Preset Picker Sheet

    private var presetPickerSheet: some View {
        NavigationStack {
            List(StrengthExercise.presets, id: \.self) { preset in
                Button {
                    exercises.append(StrengthExercise(name: preset))
                    showPresetPicker = false
                } label: {
                    Text(preset)
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(KTheme.Colors.textPrimary)
                }
                .listRowBackground(KTheme.Colors.card)
            }
            .scrollContentBackground(.hidden)
            .background(KTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPresetPicker = false }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: Actions

    private func addCustomExercise() {
        let name = customExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        exercises.append(StrengthExercise(name: name))
        customExerciseName = ""
        showCustomEntry = false
    }

    private func saveSession() {
        let validExercises = exercises.filter { !$0.sets.isEmpty }
        guard !validExercises.isEmpty else {
            saveError = "Add at least one exercise with a set."
            return
        }
        saveError = nil
        var session = StrengthSession()
        session.exercises = validExercises
        loadStore.addStrengthSession(session)
        dismiss()
    }
}

// MARK: ExerciseCard

private struct ExerciseCard: View {
    @Binding var exercise: StrengthExercise
    let onDelete: () -> Void

    var body: some View {
        KCard(elevated: true) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                exerciseHeader
                setRows
                addSetButton
                exerciseSummary
            }
        }
    }

    private var exerciseHeader: some View {
        HStack {
            Text(exercise.name)
                .font(KTheme.Typography.headingSmall)
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(KTheme.Colors.danger)
            }
        }
    }

    private var setRows: some View {
        VStack(spacing: KTheme.Spacing.xs) {
            ForEach(exercise.sets.indices, id: \.self) { setIdx in
                SetRow(set: $exercise.sets[setIdx], setNumber: setIdx + 1) {
                    exercise.sets.remove(at: setIdx)
                }
            }
        }
    }

    private var addSetButton: some View {
        Button {
            exercise.sets.append(ExerciseSet())
        } label: {
            HStack(spacing: KTheme.Spacing.xs) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                Text("Add Set")
                    .font(KTheme.Typography.label)
            }
            .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    private var exerciseSummary: some View {
        HStack {
            summaryPill(label: "Vol", value: String(format: "%.0f kg", exercise.totalVolumeKg))
            summaryPill(label: "Est 1RM", value: String(format: "%.1f kg", exercise.estimated1RM))
        }
    }

    private func summaryPill(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textSecondary)
            Text(value)
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
        .padding(.horizontal, KTheme.Spacing.sm)
        .padding(.vertical, KTheme.Spacing.xs)
        .background(KTheme.Colors.accentPrimary.opacity(0.1).cornerRadius(KTheme.Radius.sm))
    }
}

// MARK: SetRow

private struct SetRow: View {
    @Binding var set: ExerciseSet
    let setNumber: Int
    let onDelete: () -> Void

    @State private var repsText: String = ""
    @State private var weightText: String = ""

    var body: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            Text("Set \(setNumber)")
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)
                .frame(width: 44, alignment: .leading)

            TextField("Reps", text: $repsText)
                .keyboardType(.decimalPad)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KTheme.Spacing.xs)
                .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.sm))
                .onChange(of: repsText) { _, newVal in
                    set.reps = Double(newVal) ?? 0
                }

            Text("x")
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)

            TextField("kg", text: $weightText)
                .keyboardType(.decimalPad)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KTheme.Spacing.xs)
                .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.sm))
                .onChange(of: weightText) { _, newVal in
                    set.weightKg = Double(newVal) ?? 0
                }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(KTheme.Colors.danger.opacity(0.7))
            }
        }
        .onAppear {
            repsText = set.reps > 0 ? String(format: "%.0f", set.reps) : ""
            weightText = set.weightKg > 0 ? String(format: "%.1f", set.weightKg) : ""
        }
    }
}
