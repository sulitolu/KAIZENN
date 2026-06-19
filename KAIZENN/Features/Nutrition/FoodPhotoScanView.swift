import SwiftUI
import UIKit

// MARK: — Scanned Food Item Model

struct ScannedFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double

    var scaledCalories: Double { caloriesPer100g * grams / 100 }
    var scaledProtein:  Double { proteinPer100g  * grams / 100 }
    var scaledCarbs:    Double { carbsPer100g    * grams / 100 }
    var scaledFat:      Double { fatPer100g      * grams / 100 }
}

// MARK: — Claude Vision Response Models (private)

private struct VisionFoodResponse: Decodable {
    let items: [VisionFoodItem]
}

private struct VisionFoodItem: Decodable {
    let name: String
    let grams: Double
    let calories_per_100g: Double
    let protein_per_100g: Double
    let carbs_per_100g: Double
    let fat_per_100g: Double
}

// MARK: — Food Photo Scan View

struct FoodPhotoScanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nutritionStore: NutritionStore
    @Environment(\.dismiss) var dismiss

    let mealType: MealEntry.MealType

    @State private var selectedImage: UIImage? = nil
    @State private var showPicker = false
    @State private var isScanning = false
    @State private var scannedItems: [ScannedFoodItem] = []
    @State private var errorMessage: String? = nil
    @State private var showResults = false

    // Gram text fields keyed by item id
    @State private var gramInputs: [UUID: String] = [:]

    init(mealType: MealEntry.MealType = .snack) {
        self.mealType = mealType
    }

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()

                if showResults {
                    resultsView
                } else {
                    scanPromptView
                }
            }
            .navigationTitle("Scan Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                if showResults {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showResults = false
                            scannedItems = []
                        } label: {
                            Image(systemName: "arrow.uturn.left")
                                .foregroundColor(KTheme.Colors.accentPrimary)
                        }
                    }
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
                actionButtons
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
            Text("Take or choose a photo of your meal")
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var actionButtons: some View {
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

            Button {
                Task { await scanImage() }
            } label: {
                analyseButtonLabel
            }
            .disabled(selectedImage == nil || isScanning)
        }
    }

    @ViewBuilder
    private var analyseButtonLabel: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            if isScanning {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.85)
                Text("Analysing...")
            } else {
                Image(systemName: "brain")
                Text("Analyse with Kai AI")
            }
        }
        .font(KTheme.Typography.label)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(KTheme.Spacing.md)
        .background(
            selectedImage == nil
                ? AnyShapeStyle(KTheme.Colors.border)
                : AnyShapeStyle(KTheme.Colors.brandGradient)
        )
        .cornerRadius(KTheme.Radius.md)
    }

    // MARK: Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KTheme.Spacing.lg) {
                if let image = selectedImage {
                    thumbnailHeader(image: image)
                }

                itemsList

                totalCard

                KButton(title: "Log Meal", isLoading: false) {
                    logMeal()
                }
                .disabled(scannedItems.isEmpty)

                Color.clear.frame(height: KTheme.Spacing.xxl)
            }
            .padding(KTheme.Spacing.md)
        }
    }

    private func thumbnailHeader(image: UIImage) -> some View {
        HStack(spacing: KTheme.Spacing.md) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: KTheme.Radius.sm))

            VStack(alignment: .leading, spacing: 4) {
                Text("Scan Results")
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(KTheme.Colors.textPrimary)
                Text("\(scannedItems.count) item\(scannedItems.count == 1 ? "" : "s") detected")
                    .font(KTheme.Typography.bodySmall)
                    .foregroundColor(KTheme.Colors.textSecondary)
                Text(mealType.displayName)
                    .font(KTheme.Typography.caption)
                    .foregroundColor(Color(hex: mealType.color))
            }
            Spacer()
        }
    }

    private var itemsList: some View {
        VStack(spacing: KTheme.Spacing.sm) {
            ForEach($scannedItems) { $item in
                ScannedItemRow(item: $item, gramInput: gramInputBinding(for: item.id))
            }
        }
    }

    private var totalCard: some View {
        let totalCal  = scannedItems.map(\.scaledCalories).reduce(0, +)
        let totalPro  = scannedItems.map(\.scaledProtein).reduce(0, +)
        let totalCarb = scannedItems.map(\.scaledCarbs).reduce(0, +)
        let totalFat  = scannedItems.map(\.scaledFat).reduce(0, +)

        return KCard(elevated: true) {
            VStack(spacing: KTheme.Spacing.md) {
                HStack {
                    Text("Total")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(totalCal)) kcal")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
                HStack {
                    MacroChip(label: "P", value: Int(totalPro),  color: KTheme.Colors.accentSecondary)
                    MacroChip(label: "C", value: Int(totalCarb), color: KTheme.Colors.accentAmber)
                    MacroChip(label: "F", value: Int(totalFat),  color: KTheme.Colors.accentTertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: Gram Input Binding Helper

    private func gramInputBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { gramInputs[id] ?? "" },
            set: { newVal in
                gramInputs[id] = newVal
                if let grams = Double(newVal), grams > 0,
                   let idx = scannedItems.firstIndex(where: { $0.id == id }) {
                    scannedItems[idx].grams = grams
                }
            }
        )
    }

    // MARK: Scan

    @MainActor
    private func scanImage() async {
        guard let image = selectedImage else { return }
        isScanning = true
        errorMessage = nil

        let sport    = appState.userProfile.sportProfile.sport.displayName
        let position = appState.userProfile.sportProfile.position
        let positionNote = position.isEmpty ? "" : " playing \(position)"

        let systemPrompt = """
        You are a sports nutrition AI assistant for a \(sport) athlete\(positionNote). \
        Analyse the meal photo and identify all visible food items. \
        For each item, estimate the portion in grams and provide accurate macronutrient values per 100g. \
        Respond ONLY with a valid JSON object matching this schema exactly — no markdown, no explanation:
        {"items":[{"name":"Food Name","grams":100,"calories_per_100g":200,"protein_per_100g":15,"carbs_per_100g":25,"fat_per_100g":5}]}
        If no food is visible, return {"items":[]}.
        """

        do {
            let rawText = try await ClaudeService.chatWithImage(image: image, systemPrompt: systemPrompt)

            // Strip markdown code fences if present
            let cleaned = rawText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8) else {
                throw ClaudeError.requestFailed("Could not encode response as UTF-8")
            }

            let response = try JSONDecoder().decode(VisionFoodResponse.self, from: jsonData)

            scannedItems = response.items.map { v in
                ScannedFoodItem(
                    name:              v.name,
                    grams:             v.grams,
                    caloriesPer100g:   v.calories_per_100g,
                    proteinPer100g:    v.protein_per_100g,
                    carbsPer100g:      v.carbs_per_100g,
                    fatPer100g:        v.fat_per_100g
                )
            }

            // Populate gram inputs
            gramInputs = Dictionary(uniqueKeysWithValues: scannedItems.map { ($0.id, String(Int($0.grams))) })

            if scannedItems.isEmpty {
                errorMessage = "No food items were detected. Try a clearer photo."
            } else {
                showResults = true
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
    }

    // MARK: Log Meal

    private func logMeal() {
        for item in scannedItems {
            let food = FoodItem(
                name:            item.name,
                caloriesPer100g: item.caloriesPer100g,
                proteinPer100g:  item.proteinPer100g,
                carbsPer100g:    item.carbsPer100g,
                fatPer100g:      item.fatPer100g
            )
            let entry = MealEntry(mealType: mealType, food: food, gramsConsumed: item.grams)
            nutritionStore.addEntry(entry)
        }
        dismiss()
    }
}

// MARK: — Scanned Item Row

private struct ScannedItemRow: View {
    @Binding var item: ScannedFoodItem
    @Binding var gramInput: String

    var body: some View {
        KCard {
            VStack(spacing: KTheme.Spacing.sm) {
                itemHeader
                gramEditor
                macroChips
            }
        }
    }

    private var itemHeader: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(KTheme.Colors.accentPrimary)
            Text(item.name)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Text("\(Int(item.scaledCalories)) kcal")
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    private var gramEditor: some View {
        HStack {
            Text("Amount")
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textSecondary)
            Spacer()
            TextField("grams", text: $gramInput)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(KTheme.Typography.headingSmall)
                .foregroundColor(KTheme.Colors.textPrimary)
                .frame(width: 60)
            Text("g")
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.textSecondary)
        }
        .padding(.horizontal, KTheme.Spacing.xs)
        .padding(.vertical, KTheme.Spacing.xs)
        .background(KTheme.Colors.surface)
        .cornerRadius(KTheme.Radius.sm)
    }

    private var macroChips: some View {
        HStack(spacing: KTheme.Spacing.xs) {
            MacroChip(label: "P", value: Int(item.scaledProtein),  color: KTheme.Colors.accentSecondary)
            MacroChip(label: "C", value: Int(item.scaledCarbs),    color: KTheme.Colors.accentAmber)
            MacroChip(label: "F", value: Int(item.scaledFat),      color: KTheme.Colors.accentTertiary)
            Spacer()
            Text(String(format: "%.0f cal/100g", item.caloriesPer100g))
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)
        }
    }
}

// MARK: — Macro Chip

private struct MacroChip: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(KTheme.Typography.caption)
                .foregroundColor(color.opacity(0.8))
            Text("\(value)g")
                .font(KTheme.Typography.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(KTheme.Radius.pill)
    }
}

// MARK: — Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
