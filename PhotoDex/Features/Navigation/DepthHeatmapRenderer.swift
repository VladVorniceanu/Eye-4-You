//
//  DepthHeatmapRenderer.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/29/26.
//

import ARKit
import UIKit

/// Converts an ARFrame depth buffer into a false-colour UIImage for real-time
/// debugging. The colour coding matches the zone safety levels shown in the UI:
///
///   dark blue-grey  → no data / beyond sensor range
///   green           → safe   (> 3 m)
///   yellow / lime   → caution (1.5 – 3 m)
///   orange          → warning (0.5 – 1.5 m)
///   red             → danger  (< 0.5 m)
///
/// Rendered at half LiDAR resolution (128 × 96) for performance, then returned
/// with UIImage orientation `.right` so it displays correctly in portrait mode.
///
/// Not thread-safe: call from a single serial queue (DepthNavigator.queue).
final class DepthHeatmapRenderer {

    func render(frame: ARFrame) -> UIImage? {
        guard let depth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }
        return buildImage(from: depth.depthMap)
    }

    // MARK: - Private

    private func buildImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let srcW = CVPixelBufferGetWidth(pixelBuffer)    // ≈ 256
        let srcH = CVPixelBufferGetHeight(pixelBuffer)   // ≈ 192
        guard srcW > 0, srcH > 0,
              let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let src  = base.bindMemory(to: Float32.self, capacity: srcW * srcH)
        let step = 2                    // sub-sample 2× → 128 × 96
        let dstW = srcW / step
        let dstH = srcH / step

        // RGBA byte array (4 bytes per pixel, alpha always 255)
        var rgba = [UInt8](repeating: 255, count: dstW * dstH * 4)

        for y in 0..<dstH {
            for x in 0..<dstW {
                let d = src[(y * step) * srcW + (x * step)]
                let (r, g, b) = colorForDepth(d)
                let i = (y * dstW + x) * 4
                rgba[i] = r; rgba[i+1] = g; rgba[i+2] = b   // rgba[i+3] already 255
            }
        }

        let space = CGColorSpaceCreateDeviceRGB()
        let info  = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard
            let provider = CGDataProvider(data: Data(rgba) as CFData),
            let cg = CGImage(
                width: dstW, height: dstH,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: dstW * 4,
                space: space, bitmapInfo: info,
                provider: provider,
                decode: nil, shouldInterpolate: true,
                intent: .defaultIntent
            )
        else { return nil }

        // .right rotates the landscape LiDAR buffer 90° CW for portrait display
        return UIImage(cgImage: cg, scale: 1.0, orientation: .right)
    }

    /// Maps a depth value (metres) to an RGB heat-map colour.
    private func colorForDepth(_ d: Float) -> (UInt8, UInt8, UInt8) {
        guard d.isFinite, d >= 0.05 else {
            return (20, 20, 50)            // dark = no data or out-of-range
        }
        switch d {
        case ..<0.5:
            // Red → dark-orange  (immediate danger)
            let t = d / 0.5
            return (255, UInt8(t * 70), UInt8(t * 30))
        case 0.5..<1.5:
            // Orange             (close / warning)
            let t = (d - 0.5) / 1.0
            return (255, UInt8(70 + t * 115), 0)
        case 1.5..<3.0:
            // Yellow → lime      (moderate)
            let t = (d - 1.5) / 1.5
            return (UInt8((1 - t) * 255), 210, 0)
        case 3.0..<5.0:
            // Green              (safe)
            return (0, 210, UInt8((d - 3) / 2 * 60))
        default:
            // Teal               (very far / open)
            return (0, 150, 90)
        }
    }
}
