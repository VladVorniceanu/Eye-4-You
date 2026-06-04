//
//  DepthFrameProcessor.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/28/26.
//

import ARKit
import Foundation

/// Converts raw ARDepthData into an ObstacleSnapshot by partitioning the
/// 256 × 192 depth map into a 3 (cols) × 2 (rows) grid and computing the
/// 5th-percentile distance per cell — ignoring low-confidence and out-of-range pixels.
///
/// Not thread-safe: access only from a single serial queue (DepthNavigator.queue).
final class DepthFrameProcessor {

    private var prevLowerCenter: Float?
    private var consecutiveJumpCount = 0

    // MARK: - Public

    /// Returns nil when the frame contains no usable depth buffer.
    func process(frame: ARFrame) -> ObstacleSnapshot? {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }

        let depthMap = depthData.depthMap
        let confMap  = depthData.confidenceMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let c = confMap { CVPixelBufferLockBaseAddress(c, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let c = confMap { CVPixelBufferUnlockBaseAddress(c, .readOnly) }
        }

        let w = CVPixelBufferGetWidth(depthMap)
        let h = CVPixelBufferGetHeight(depthMap)
        guard w > 0, h > 0,
              let depthBase = CVPixelBufferGetBaseAddress(depthMap)
        else { return nil }

        let depthPtr = depthBase.bindMemory(to: Float32.self, capacity: w * h)

        var confPtr: UnsafeMutablePointer<UInt8>?
        if let c = confMap, let base = CVPixelBufferGetBaseAddress(c) {
            confPtr = base.bindMemory(to: UInt8.self, capacity: w * h)
        }

        let cells: [[ZoneReading]] = (0..<2).map { row in
            (0..<3).map { col in
                sampleCell(col: col, row: row, cols: 3, rows: 2,
                           w: w, h: h, depth: depthPtr, conf: confPtr)
            }
        }

        return ObstacleSnapshot(timestamp: frame.timestamp, cells: cells)
    }

    /// Returns a step / dropoff event when the lower-center zone jumps > 0.20 m
    /// on two consecutive frames while the device is roughly level (±30°).
    func detectStep(snapshot: ObstacleSnapshot, cameraPitch: Float) -> NavigationEvent? {
        guard abs(cameraPitch) < .pi / 6 else {
            prevLowerCenter = snapshot.lowerCenter?.distance
            consecutiveJumpCount = 0
            return nil
        }

        guard let current = snapshot.lowerCenter?.distance, current.isFinite,
              let prev = prevLowerCenter, prev.isFinite
        else {
            prevLowerCenter = snapshot.lowerCenter?.distance
            return nil
        }
        prevLowerCenter = current

        let delta = current - prev
        if abs(delta) > 0.20 {
            consecutiveJumpCount += 1
        } else {
            consecutiveJumpCount = 0
            return nil
        }

        // Two consecutive frames confirms the jump is not sensor noise.
        guard consecutiveJumpCount >= 2 else { return nil }
        consecutiveJumpCount = 0
        return delta > 0 ? .stepDown : .stepUp
    }

    // MARK: - Private

    private func sampleCell(col: Int, row: Int, cols: Int, rows: Int,
                            w: Int, h: Int,
                            depth: UnsafeMutablePointer<Float32>,
                            conf: UnsafeMutablePointer<UInt8>?) -> ZoneReading {
        let x0 = col * w / cols
        let x1 = (col + 1) * w / cols
        let y0 = row * h / rows
        let y1 = (row + 1) * h / rows

        var valid: [Float] = []
        valid.reserveCapacity((x1 - x0) * (y1 - y0) / 4)

        for y in stride(from: y0, to: y1, by: 2) {
            for x in stride(from: x0, to: x1, by: 2) {
                let idx = y * w + x
                // ARConfidenceLevel raw values: 0 = low, 1 = medium, 2 = high
                if let conf, conf[idx] < 1 { continue }
                let d = depth[idx]
                guard d.isFinite, d >= 0.1, d <= 10.0 else { continue }
                valid.append(d)
            }
        }

        guard !valid.isEmpty else {
            return ZoneReading(distance: .infinity, col: col, row: row)
        }

        valid.sort()
        let p5 = max(0, Int(Float(valid.count) * 0.05))
        return ZoneReading(distance: valid[p5], col: col, row: row)
    }
}
