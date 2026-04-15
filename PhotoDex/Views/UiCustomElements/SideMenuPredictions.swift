import SwiftUI

struct SideMenuPredictions: View {
    @Binding var isPresented: Bool
    let predictions: [Prediction]
    let selectedItems: Set<UUID>
    let onSelectionChanged: (UUID, Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 0) {
                    header

                    if predictions.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(predictions, id: \.id) { item in
                                PredictionRow(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id),
                                    onSelectionChanged: { onSelectionChanged(item.id, $0) }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(width: min(360, geometry.size.width * 0.82))
                .frame(maxHeight: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 22, x: -8, y: 12)
                .padding(.vertical, 12)
                .padding(.trailing, 8)
                .offset(x: isPresented ? 0 : geometry.size.width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Predictii")
                    .font(.title3.weight(.semibold))
                Text("\(predictions.count) rezultate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Nu exista predictii de afisat")
                .font(.headline)
            Text("Dupa analiza, lista rezultatelor va aparea aici.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PredictionRow: View {
    let item: Prediction
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isSelected }, set: onSelectionChanged)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.label.capitalized)
                    .font(.body.weight(.medium))
                Text("\(String(format: "%.1f", item.confidence * 100))% incredere")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
