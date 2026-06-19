import SwiftUI
import UIKit

// MARK: - Training Menu Response Models (private)

private struct TrainingMenuResponse: Decodable {
    let exercises: [TRExercise]
}

private struct TRExercise: Decodable {
    let name: String
    let sets: [TRSet]
}

private struct TRSet: Decodable {
    let reps: Double
    let weight_kg: Double
}

// MARK: - Training Menu Scan View

struct TrainingMenuScanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedImage: UIImage? = nil
    @State private var showPicker = false
    @State private var isScanning = false
    @State private var parsedSession: StrengthSession? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()

                if parsedSession != nil {
                    parsedSessionView
                } else {
                    scanPromptView
                }
            }
            .navigationTitle("Scan Training Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPicker) {
            ImagePickerView(image: $selectedImage)
        }
        .alert("Scan Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Scan Prompt

    private var scanPromptView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KTheme.Spacing.lg) {
                imagePreviewArea
                actionButtonsArea
                Color.clear.frame(height: KTheme.Spacing.xxl)
            }
            .padding(KTheme.Spacing.md)
        }
    }

    private var imagePreviewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .fill(KTheme.Colors.card)
                .frame(height: 280)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: KTheme.Radius.lg))
            } else {
                placeholderContent
            }
        }
    }

    private var placeholderContent: some View {
        VStack(spacing: KTheme.Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(KTheme.Colors.accentPrimary.opacity(0.6))
            Text("Photo your whiteboard, printed plan, or handwritten session")
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KTheme.Spacing.md)
        }
    }

    private var actionButtonsArea: some View {
        VStack(spacing: KTheme.Spacing.sm) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: KTheme.Spacing.sm) {
                    Image(systemName: selectedImage == nil ? "camera.fill" : "photo.on.rectangle")
                    Text(selectedImage == nil ? "Take Photo / Choose" : "Change Photo")
                }
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(KTheme.Spacing.md)
                .background(KTheme.Colors.card)
                .cornerRadius(KTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(KTheme.Colors.border, lineWidth: 1)
                )
            }

            KButton(title: "Extract Session with Kai AI", isLoading: isScanning) {
                Task { await scanImage() }
            }
            .disabled(selectedImage == nil || isScanning)
        }
    }

    // MARK: Parsed Session View

    private var parsedSessionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KTheme.Spacing.lg) {
                parsedHeader
                if let session = parsedSession {
                    exercisesList(session: session)
                }
                saveAndRescanButtons
                Color.clear.frame(height: KTheme.Spacing.xxl)
            }
            .padding(KTheme.Spacing.md)
        }
    }

    private var parsedHeader: some View {
        HStack(spacing: KTheme.Spacing.md) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: KTheme.Radius.sm))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Session Extracted")
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(KTheme.Colors.textPrimary)
                if let session = parsedSession {
                    Text("\(session.exercises.count) exercise\(session.exercises.count == 1 ? "" : "s") detected")
                        .font(KTheme.Typography.bodySmall)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func exercisesList(session: StrengthSession) -> some View {
        VStack(spacing: KTheme.Spacing.sm) {
            ForEach(session.exercises) { exercise in
                exerciseCard(exercise: exercise)
            }
        }
    }

    private func exerciseCard(exercise: StrengthExercise) -> some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                HStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KTheme.Colors.accentPrimary)
                    Text(exercise.name)
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f kg vol", exercise.totalVolumeKg))
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.textTertiary)
                            Spacer()
                            Text(String(format: "%.0f reps x %.1f kg", set.reps, set.weightKg))
                                .font(KTheme.Typography.label)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var saveAndRescanButtons: some View {
        VStack(spacing: KTheme.Spacing.sm) {
            KButton(title: "Save Session", style: .primary, isLoading: false) {
                if let session = parsedSession {
                    loadStore.addStrengthSession(session)
                    dismiss()
                }
            }
            .disabled(parsedSession == nil)

            KButton(title: "Re-scan", style: .secondary, isLoading: false) {
                parsedSession = nil
                selectedImage = nil
                errorMessage = nil
            }
        }
    }

    // MARK: Scan

    @MainActor
    private func scanImage() async {
        guard let image = selectedImage else { return }
        isScanning = true
        errorMessage = nil

        let sport = appState.userProfile.sportProfile.sport.displayName

        let systemPrompt = """
        You are a strength training AI assistant for a \(sport) athlete. \
        Analyse the training program photo and extract all exercises with their sets, reps, and weights. \
        Respond ONLY with a valid JSON object matching this schema exactly — no markdown, no explanation:
        {"exercises":[{"name":"Exercise Name","sets":[{"reps":5,"weight_kg":100}]}]}
        If no exercises are visible, return {"exercises":[]}.
        Weights should always be in kilograms. If weights are listed in lbs, convert to kg. \
        If no weight is specified for a set, use 0.
        """

        do {
            let rawText = try await ClaudeService.chatWithImage(image: image, systemPrompt: systemPrompt)

            let cleaned = rawText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8) else {
                throw ClaudeError.requestFailed("Could not encode response as UTF-8")
            }

            let response = try JSONDecoder().decode(TrainingMenuResponse.self, from: jsonData)

            if response.exercises.isEmpty {
                errorMessage = "No exercises were detected. Try a clearer photo."
            } else {
                var session = StrengthSession()
                session.date = Date()
                session.exercises = response.exercises.map { trEx in
                    var exercise = StrengthExercise(name: trEx.name)
                    exercise.sets = trEx.sets.map { trSet in
                        var s = ExerciseSet()
                        s.reps = trSet.reps
                        s.weightKg = trSet.weight_kg
                        return s
                    }
                    return exercise
                }
                parsedSession = session
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }
}
