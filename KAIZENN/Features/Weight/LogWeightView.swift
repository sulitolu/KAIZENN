import SwiftUI

struct LogWeightView: View {
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) var dismiss

    @State private var weight: String = ""
    @State private var bodyFat: String = ""
    @State private var notes: String = ""
    @State private var date = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: KTheme.Spacing.lg) {
                    // Big weight input (hero)
                    KCard(elevated: true) {
                        VStack(spacing: KTheme.Spacing.sm) {
                            Text("WEIGHT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(KTheme.Colors.accentPrimary.opacity(0.8))
                                .tracking(1.5)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TextField("0.0", text: $weight)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 60, weight: .black, design: .rounded))
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize()
                                Text("kg")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundColor(KTheme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, KTheme.Spacing.md)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                            .stroke(KTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 0.5)
                    )
                    .shadow(color: KTheme.Colors.accentPrimary.opacity(0.15), radius: 20, x: 0, y: 0)

                    // Optional metrics
                    KCard {
                        VStack(spacing: KTheme.Spacing.md) {
                            HStack {
                                Text("BODY FAT %")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(KTheme.Colors.textSecondary)
                                    .tracking(1.5)
                                Spacer()
                                TextField("Optional", text: $bodyFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("%").foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Divider().background(KTheme.Colors.border)
                            HStack {
                                Text("DATE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(KTheme.Colors.textSecondary)
                                    .tracking(1.5)
                                Spacer()
                                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                            }
                        }
                    }

                    KTextField(placeholder: "Notes (how are you feeling?)", text: $notes, icon: "note.text")

                    Spacer()

                    KButton(title: "Save", isLoading: isSaving) {
                        save()
                    }
                    .disabled(Double(weight) == nil)
                    .padding(.bottom, KTheme.Spacing.xxl)
                }
                .padding(KTheme.Spacing.md)
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let last = weightStore.latestWeight {
                weight = String(format: "%.1f", last)
            }
        }
    }

    private func save() {
        guard let kg = Double(weight) else { return }
        isSaving = true
        var measurement = BodyMeasurement(date: date, weightKg: kg)
        measurement.bodyFatPercentage = Double(bodyFat)
        measurement.notes = notes.isEmpty ? nil : notes
        weightStore.addMeasurement(measurement)
        Task { await healthKitManager.saveWeight(kg, date: date) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}
