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

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)

                Spacer()

                if scannerAvailable {
                    Text("Align the barcode within the frame")
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, KTheme.Spacing.md)
                        .padding(.vertical, KTheme.Spacing.sm)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(KTheme.Radius.md)
                        .padding(.bottom, KTheme.Spacing.xl)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var unsupportedView: some View {
        VStack(spacing: KTheme.Spacing.md) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(KTheme.Colors.textSecondary)
            Text("Barcode Scanning Unavailable")
                .font(KTheme.Typography.headingMedium)
                .foregroundColor(.white)
            Text("This device or simulator doesn't support live barcode scanning. Try on a physical device.")
                .font(KTheme.Typography.bodySmall)
                .foregroundColor(KTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
