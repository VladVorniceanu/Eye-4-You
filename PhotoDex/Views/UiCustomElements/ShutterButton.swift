import SwiftUI

struct ShutterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 82, height: 82)

                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Captureaza fotografia")
    }
}
