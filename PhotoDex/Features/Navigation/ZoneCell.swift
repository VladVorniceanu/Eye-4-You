//
//  ZoneCell.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/4/26.
//

import SwiftUI

/// A single distance-zone tile in the 3-column zone grid on the navigation screen.
struct ZoneCell: View {
    let label: String
    let distance: Float

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))

            Text(distanceString)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(zoneColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(distanceString)")
    }

    private var distanceString: String {
        distance.isFinite ? String(format: "%.1f m", distance) : "—"
    }

    private var zoneColor: Color {
        guard distance.isFinite else { return .white.opacity(0.4) }
        switch distance {
        case ..<0.5:    return .red
        case 0.5..<1.5: return .orange
        case 1.5..<3.0: return .yellow
        default:        return .green
        }
    }
}
