import SwiftUI

struct PhotoReview: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imagePreview

                VStack(alignment: .leading, spacing: 8) {
                    Text("Imagine pregatita pentru analiza")
                        .font(.title3.weight(.semibold))
                    Text("Verifica rapid cadrul si continua cand esti pregatit. Analiza va afisa predictiile direct peste imagine.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                NavigationLink(destination: MLAnalysisView(image: image, isPresented: $isPresented)) {
                    Label("Analizeaza imaginea", systemImage: "sparkle.magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Previzualizare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Inchide") {
                    isPresented = false
                }
            }
        }
    }

    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 18, y: 10)
    }
}
