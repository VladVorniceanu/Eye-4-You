import SwiftUI

struct FlashButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 20, weight: .medium))
        }
        .tint(isOn ? .yellow : .white)
    }
}
