import SwiftUI
import VisionKit

// MARK: — Barcode Scanner Sheet

struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) var dismiss
    let onScan: (String) -> Void

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scannerAvailable {
                BarcodeScannerRepresentable { barcode in
                    onScan(barcode)
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                unsupportedView
            }

            // Premium overlay
            VStack {
                topBar
                Spacer()
                if scannerAvailable {
                    scanFrame
                    Spacer()
                    instructionLabel
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("BARCODE SCANNER")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.accentAmber)
                    .tracking(2)
                Text("KAIZENN NUTRITION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.accentAmber.opacity(0.5))
                    .tracking(1.5)
            }
            Spacer()
            // Balance the close button
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(KTheme.Spacing.md)
        .padding(.top, KTheme.Spacing.md)
    }

    // MARK: Scan frame — premium amber accent corners

    private var scanFrame: some View {
        ZStack {
            // Dimmed areas outside frame via overlay on the full screen is handled by
            // the system scanner; we add a decorative accent frame on top.
            RoundedRectangle(cornerRadius: 16)
                .stroke(KTheme.Colors.accentAmber.opacity(0.6), lineWidth: 1.5)
                .frame(width: 260, height: 140)
                .shadow(color: KTheme.Colors.accentAmber.opacity(0.35), radius: 12, x: 0, y: 0)

            // Corner accents (top-left, top-right, bottom-left, bottom-right)
            ScanCorners(size: 24, lineWidth: 3, color: KTheme.Colors.accentAmber)
                .frame(width: 260, height: 140)
        }
    }

    // MARK: Instruction label

    private var instructionLabel: some View {
        Text("ALIGN BARCODE WITHIN FRAME")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(KTheme.Colors.accentAmber.opacity(0.9))
            .tracking(2)
            .padding(.horizontal, KTheme.Spacing.lg)
            .padding(.vertical, KTheme.Spacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(KTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.md)
                    .stroke(KTheme.Colors.accentAmber.opacity(0.3), lineWidth: 0.5)
            )
            .padding(.bottom, KTheme.Spacing.xxl)
    }

    // MARK: Unsupported view

    private var unsupportedView: some View {
        VStack(spacing: KTheme.Spacing.md) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(KTheme.Colors.accentAmber.opacity(0.5))
                .kGlow(color: KTheme.Colors.accentAmber, radius: 20)

            Text("SCANNER UNAVAILABLE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.accentAmber)
                .tracking(2)

            Text("This device or simulator doesn't support live barcode scanning. Try on a physical device.")
                .font(KTheme.Typography.bodySmall)
                .foregroundColor(KTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — Scan Corner Decorations

private struct ScanCorners: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            ZStack {
                singleCorner(x: 0,  y: 0,  dx:  size, dy:  size).stroke(color, style: style)
                singleCorner(x: w,  y: 0,  dx: -size, dy:  size).stroke(color, style: style)
                singleCorner(x: 0,  y: h,  dx:  size, dy: -size).stroke(color, style: style)
                singleCorner(x: w,  y: h,  dx: -size, dy: -size).stroke(color, style: style)
            }
        }
    }

    private func singleCorner(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x + dx, y: y))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + dy))
        }
    }
}

// MARK: — UIViewControllerRepresentable wrapper

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    hasScanned = true
                    onScan(payload)
                    break
                }
            }
        }
    }
}
