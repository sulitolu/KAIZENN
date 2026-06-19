import SwiftUI
import UniformTypeIdentifiers

struct GPSImportView: View {
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) private var dismiss

    // MARK: File import state
    @State private var showFilePicker = false
    @State private var parsedSession: GPSSession? = nil
    @State private var parseError: String? = nil

    // MARK: Manual entry state
    @State private var manualDistanceKm = ""
    @State private var manualPlayerLoad = ""
    @State private var manualSprintCount = ""
    @State private var manualHSRPercent = ""
    @State private var manualDurationMin = ""

    @State private var manualError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KTheme.Spacing.lg) {
                    catapultSection
                    divider
                    manualSection
                }
                .padding(KTheme.Spacing.md)
            }
            .background(KTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Import GPS Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: Catapult CSV Section
    private var catapultSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                sectionHeader(icon: "antenna.radiowaves.left.and.right", title: "Catapult CSV")

                if let session = parsedSession {
                    parsedPreview(session: session)
                    KButton(title: "Save Session", style: .primary) {
                        loadStore.addGPSSession(session)
                        dismiss()
                    }
                } else {
                    if let error = parseError {
                        Text(error)
                            .font(KTheme.Typography.bodySmall)
                            .foregroundColor(KTheme.Colors.danger)
                    }
                    KButton(title: "Select CSV File", style: .secondary) {
                        parseError = nil
                        showFilePicker = true
                    }
                }
            }
        }
    }

    private var divider: some View {
        HStack {
            Rectangle()
                .fill(KTheme.Colors.border)
                .frame(height: 0.5)
            Text("or enter manually")
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)
            Rectangle()
                .fill(KTheme.Colors.border)
                .frame(height: 0.5)
        }
    }

    // MARK: Manual Entry Section
    private var manualSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                sectionHeader(icon: "pencil", title: "Manual Entry")

                VStack(spacing: KTheme.Spacing.sm) {
                    KTextField(placeholder: "Distance (km)", text: $manualDistanceKm, keyboardType: .decimalPad)
                    KTextField(placeholder: "Player Load", text: $manualPlayerLoad, keyboardType: .decimalPad)
                    KTextField(placeholder: "Sprint Count", text: $manualSprintCount, keyboardType: .numberPad)
                    KTextField(placeholder: "High Speed Running %", text: $manualHSRPercent, keyboardType: .decimalPad)
                    KTextField(placeholder: "Duration (minutes)", text: $manualDurationMin, keyboardType: .decimalPad)
                }

                if let error = manualError {
                    Text(error)
                        .font(KTheme.Typography.bodySmall)
                        .foregroundColor(KTheme.Colors.danger)
                }

                KButton(title: "Save Manual Entry", style: .primary) {
                    saveManualSession()
                }
            }
        }
    }

    // MARK: Helpers

    @ViewBuilder
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: KTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KTheme.Colors.accentPrimary)
            Text(title)
                .font(KTheme.Typography.headingSmall)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
    }

    @ViewBuilder
    private func parsedPreview(session: GPSSession) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
            previewRow(label: "Source", value: session.source.displayName)
            previewRow(label: "Distance", value: String(format: "%.2f km", session.distanceMeters / 1000))
            previewRow(label: "Player Load", value: String(format: "%.1f", session.playerLoad))
            previewRow(label: "Sprints", value: "\(session.sprintCount)")
            previewRow(label: "HSR", value: String(format: "%.1f%%", session.highSpeedRunningPercent))
            if session.durationSeconds > 0 {
                previewRow(label: "Duration", value: String(format: "%.0f min", session.durationSeconds / 60))
            }
        }
        .padding(KTheme.Spacing.sm)
        .background(KTheme.Colors.cardElevated.cornerRadius(KTheme.Radius.md))
    }

    private func previewRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            parseError = "Could not open file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let csv = try String(contentsOf: url, encoding: .utf8)
                if let session = CatapultParser.parse(csvString: csv) {
                    parsedSession = session
                    parseError = nil
                } else {
                    parseError = "Could not parse CSV — check column headers."
                }
            } catch {
                parseError = "Failed to read file: \(error.localizedDescription)"
            }
        }
    }

    private func saveManualSession() {
        guard let distKm = Double(manualDistanceKm), distKm > 0 else {
            manualError = "Enter a valid distance."
            return
        }
        manualError = nil
        var session = GPSSession()
        session.source = .manual
        session.distanceMeters = distKm * 1000
        session.playerLoad = Double(manualPlayerLoad) ?? 0
        session.sprintCount = Int(manualSprintCount) ?? 0
        session.highSpeedRunningPercent = Double(manualHSRPercent) ?? 0
        session.durationSeconds = (Double(manualDurationMin) ?? 0) * 60
        loadStore.addGPSSession(session)
        dismiss()
    }
}
