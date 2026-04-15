import SwiftUI

struct FlashButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "bolt.fill" : "bolt.slash")
                .font(.headline.weight(.semibold))
                .foregroundStyle(isOn ? Color.yellow : Color.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Opreste blitul" : "Porneste blitul")
    }
}
