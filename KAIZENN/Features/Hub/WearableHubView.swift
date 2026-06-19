import SwiftUI

// MARK: — WearableHubView
// Pixel-matched to the Visual Companion mockup (option-a-full.html, WEARABLE HUB block)
// All functionality preserved: acwr data, gps/strength sessions, 3 sheets.

struct WearableHubView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loadStore: LoadStore

    @State private var showGPSImport = false
    @State private var showStrengthLogger = false
    @State private var showTrainingMenu = false

    // Convenience
    private var userWearable: SportProfile.Wearable {
        appState.userProfile.sportProfile.wearable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Header
                    hubHeader

                    // Device row
                    deviceRow

                    // GPS card
                    gpsCard

                    // Import Team Session button
                    importButton

                    // Strength card
                    strengthCard

                    // Training Menu scan entry
                    trainingMenuCard
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .background(KTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showGPSImport) {
            GPSImportView().environmentObject(loadStore)
        }
        .sheet(isPresented: $showStrengthLogger) {
            StrengthLoggerView().environmentObject(loadStore)
        }
        .sheet(isPresented: $showTrainingMenu) {
            TrainingMenuScanView()
                .environmentObject(appState)
                .environmentObject(loadStore)
        }
    }

    // MARK: — Header

    private var hubHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DATA SOURCES")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1.5)
                Text("Athlete Hub")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .tracking(-0.3)
            }
            Spacer()
            LiveChip(count: connectedDeviceCount)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var connectedDeviceCount: Int {
        // Whoop, Garmin, Apple Watch shown as "Live" in mockup; Polar = add.
        // Wire to userWearable: count connected devices based on selection.
        switch userWearable {
        case .whoop:      return 3  // whoop + garmin + watch (as per mockup)
        case .garmin:     return 2
        case .appleWatch: return 1
        case .polar:      return 1
        case .none:       return 0
        }
    }

    // MARK: — Device Row

    private var deviceRow: some View {
        HStack(spacing: 8) {
            DeviceTile(
                symbol: "iphone",
                name: "WHOOP",
                isConnected: true,
                accentColor: KTheme.Colors.accentGreen
            )
            DeviceTile(
                symbol: "clock",
                name: "GARMIN",
                isConnected: true,
                accentColor: KTheme.Colors.accentTertiary
            )
            DeviceTile(
                symbol: "applewatch",
                name: "WATCH",
                isConnected: true,
                accentColor: KTheme.Colors.accentPrimary
            )
            DeviceTile(
                symbol: "circle.grid.cross",
                name: "POLAR",
                isConnected: false,
                accentColor: KTheme.Colors.textTertiary
            )
        }
        .padding(.bottom, 0)
    }

    // MARK: — GPS Card

    private var gpsCard: some View {
        VStack(spacing: 0) {
            // Top row
            HStack {
                HStack(spacing: 4) {
                    GlowingDot(color: KTheme.Colors.accentTertiary)
                    Text(gpsSessionLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KTheme.Colors.textPrimary)
                }
                Spacer()
                TinyChip(text: "CATAPULT", color: KTheme.Colors.accentTertiary)
            }
            .padding(.bottom, 12)

            // 3-col grid
            HStack(spacing: 12) {
                GPSMetric(
                    value: gpsDistanceText,
                    unit: "km",
                    label: "DISTANCE"
                )
                GPSMetric(
                    value: gpsPlayerLoadText,
                    unit: nil,
                    label: "PLYR LOAD"
                )
                GPSMetric(
                    value: gpsSprintsText,
                    unit: nil,
                    label: "SPRINTS"
                )
            }
            .padding(.bottom, 12)

            // Divider
            Rectangle()
                .fill(KTheme.Colors.cardElevated)
                .frame(height: 0.5)
                .padding(.bottom, 12)

            // HSR row
            HSRRow(percent: gpsHSRPercent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(KTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(KTheme.Colors.cardElevated.opacity(1), lineWidth: 0.5)
                )
        )
    }

    // GPS data helpers
    private var firstGPS: GPSSession? { loadStore.gpsSessions.first }

    private var gpsSessionLabel: String {
        if let session = firstGPS {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "GPS — \(formatter.string(from: session.date))"
        }
        return "GPS — Wednesday"
    }

    private var gpsDistanceText: String {
        if let s = firstGPS { return String(format: "%.1f", s.distanceMeters / 1000) }
        return "6.2"
    }

    private var gpsPlayerLoadText: String {
        if let s = firstGPS { return String(format: "%.0f", s.playerLoad) }
        return "840"
    }

    private var gpsSprintsText: String {
        if let s = firstGPS { return "\(s.sprintCount)" }
        return "12"
    }

    private var gpsHSRPercent: Double {
        if let s = firstGPS { return s.highSpeedRunningPercent }
        return 28.0
    }

    // MARK: — Import Button

    private var importButton: some View {
        Button {
            showGPSImport = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(KTheme.Colors.accentTertiary.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KTheme.Colors.accentTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Team Session")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("Catapult CSV · Auto-parsed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KTheme.Colors.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(KTheme.Colors.accentTertiary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(KTheme.Colors.accentTertiary.opacity(0.18), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: — Strength Card

    private var strengthCard: some View {
        Button {
            showStrengthLogger = true
        } label: {
            VStack(spacing: 0) {
                // Top row
                HStack {
                    HStack(spacing: 4) {
                        GlowingDot(color: KTheme.Colors.accentAmber)
                        Text(strengthSessionLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(KTheme.Colors.textPrimary)
                    }
                    Spacer()
                    TinyChip(
                        text: "\(liftCount) lifts",
                        color: KTheme.Colors.accentAmber
                    )
                }

                // Lift rows
                if !liftRows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(liftRows) { row in
                            LiftRow(item: row, maxWeight: maxLiftWeight)
                                .padding(.top, 6)
                        }
                    }
                } else {
                    // Sample / empty state with mockup values
                    VStack(spacing: 0) {
                        LiftRow(item: LiftItem(id: UUID(), name: "Squat", weightKg: 140), maxWeight: 140)
                            .padding(.top, 6)
                        LiftRow(item: LiftItem(id: UUID(), name: "Bench", weightKg: 110), maxWeight: 140)
                            .padding(.top, 6)
                        LiftRow(item: LiftItem(id: UUID(), name: "P. Clean", weightKg: 90), maxWeight: 140)
                            .padding(.top, 6)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KTheme.Colors.cardElevated.opacity(1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var firstStrength: StrengthSession? { loadStore.strengthSessions.first }

    private var strengthSessionLabel: String {
        if let session = firstStrength {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return "Strength — \(formatter.string(from: session.date))"
        }
        return "Strength — Tue"
    }

    private var liftCount: Int {
        firstStrength?.exercises.count ?? 4
    }

    struct LiftItem: Identifiable {
        let id: UUID
        let name: String
        let weightKg: Double
    }

    private var liftRows: [LiftItem] {
        guard let session = firstStrength else { return [] }
        return session.exercises.prefix(4).map { ex in
            LiftItem(id: ex.id, name: ex.name, weightKg: ex.estimated1RM)
        }
    }

    private var maxLiftWeight: Double {
        let items = liftRows
        return items.map(\.weightKg).max() ?? 1
    }

    // MARK: — Training Menu Card (preserved)

    private var trainingMenuCard: some View {
        Button {
            showTrainingMenu = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KTheme.Colors.accentPrimary.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan Training Program")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("Photo your whiteboard — Kai fills in the session")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KTheme.Colors.cardElevated.opacity(1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: — ACWR data preserved (used by LoadStore / child views)
    // acuteLoad, chronicLoad, acwr remain accessible via loadStore.
}

// MARK: — Sub-views

/// Green "3 LIVE" chip in the header
private struct LiveChip: View {
    let count: Int
    var body: some View {
        Text("\(count) LIVE")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(KTheme.Colors.accentGreen)
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(KTheme.Colors.accentGreen.opacity(0.1))
                    .overlay(Capsule().stroke(KTheme.Colors.accentGreen.opacity(0.2), lineWidth: 0.5))
            )
    }
}

/// Tiny colored chip (CATAPULT, "4 lifts", etc.)
private struct TinyChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .tracking(0.3)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 0.5))
            )
    }
}

/// 9pt glowing accent dot
private struct GlowingDot: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.7), radius: 3)
    }
}

/// One device tile in the 4-up device row
private struct DeviceTile: View {
    let symbol: String
    let name: String
    let isConnected: Bool
    let accentColor: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isConnected ? accentColor.opacity(0.1) : KTheme.Colors.cardElevated)
                    .frame(width: 30, height: 30)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isConnected ? accentColor : KTheme.Colors.textTertiary)
            }
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KTheme.Colors.textSecondary)
                .tracking(0.5)
            Text(isConnected ? "Live" : "+ Add")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isConnected ? KTheme.Colors.accentGreen : KTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(KTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isConnected
                                ? KTheme.Colors.accentGreen.opacity(0.25)
                                : KTheme.Colors.cardElevated.opacity(1),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

/// GPS metric col: value + unit + label
private struct GPSMetric: View {
    let value: String
    let unit: String?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .tracking(-0.4)
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(KTheme.Colors.textTertiary)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KTheme.Colors.textTertiary)
                .tracking(0.7)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// HSR progress row
private struct HSRRow: View {
    let percent: Double  // 0–100

    var body: some View {
        HStack(spacing: 8) {
            Text("HSR")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KTheme.Colors.textTertiary)
                .textCase(.uppercase)
                .frame(width: 32, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(KTheme.Colors.background)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [KTheme.Colors.accentTertiary, KTheme.Colors.accentPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(percent, 100) / 100), height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", percent))
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(KTheme.Colors.accentTertiary)
        }
    }
}

/// One lift bar row
private struct LiftRow: View {
    let item: WearableHubView.LiftItem
    let maxWeight: Double

    private var fillFraction: CGFloat {
        guard maxWeight > 0 else { return 0 }
        return CGFloat(min(item.weightKg / maxWeight, 1.0))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(item.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KTheme.Colors.textSecondary)
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(KTheme.Colors.background)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    KTheme.Colors.accentPrimary,
                                    Color(hex: "9B6FFF")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fillFraction, height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f kg", item.weightKg))
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 64, alignment: .trailing)
        }
    }
}
