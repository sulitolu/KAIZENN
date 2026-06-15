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
                    // Big weight input
                    KCard(elevated: true) {
                        VStack(spacing: KTheme.Spacing.sm) {
                            Text("Weight").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textSecondary)
                            HStack(alignment: .bottom, spacing: 4) {
                                TextField("0.0", text: $weight)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 60, weight: .bold))
                                    .foregroundColor(KTheme.Colors.accentPrimary)
                                    .multilineTextAlignment(.center)
                                Text("kg")
                                    .font(KTheme.Typography.headingLarge)
                                    .foregroundColor(KTheme.Colors.textSecondary)
                                    .padding(.bottom, 8)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, KTheme.Spacing.md)
                    }

                    // Optional metrics
                    KCard {
                        VStack(spacing: KTheme.Spacing.md) {
                            HStack {
                                Text("Body Fat %").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
                                Spacer()
                                TextField("Optional", text: $bodyFat)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                    .font(KTheme.Typography.headingSmall)
                                Text("%").foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Divider().background(KTheme.Colors.border)
                            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .colorScheme(.dark)
                                .foregroundColor(KTheme.Colors.textPrimary)
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
