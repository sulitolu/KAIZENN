import SwiftUI

struct WearableHubPlaceholderView: View {
    var body: some View {
        ZStack {
            Color(hex: "#080810").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#4ECDC4"))
                Text("Wearable Hub")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Coming soon — GPS, Catapult data, and strength logging")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
