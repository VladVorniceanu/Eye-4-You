import SwiftUI

struct CameraSwitchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "camera.rotate.fill")
                    .font(.title3.weight(.semibold))
                Text("Camera")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 72)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
