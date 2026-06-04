//
//  PathPlanner.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 5/31/26.
//

import ARKit

/// VFH-based path planner implementing the three-stage PAD-Lite algorithm:
///   Stage 1 — BEV occupancy grid  (LiDAR depth map → top-down obstacle grid)
///   Stage 2 — Polar histogram     (BEV grid → angular obstacle density per sector)
///   Stage 3 — VFH+ steering       (histogram valleys → lowest-cost walking direction)
///
/// Not thread-safe: must be accessed only from a single serial queue (DepthNavigator.queue).
final class PathPlanner {

    /// Binary blocked/free state from the previous frame — used for hysteresis in Stage 3.
    private var previousMask: [Bool] = Array(repeating: false, count: PolarHistogram.sectorCount)
    /// Sector index chosen on the previous frame — penalises sudden direction reversals.
    private var previousSteeringSector: Int = 0
    /// World-space Y of the floor plane, calibrated from ARKit horizontal plane anchors.
    /// Stays .nan until a horizontal ARPlaneAnchor is received; falls back to a camera-height
    /// estimate (cameraY − 1.2 m) when uncalibrated.
    private(set) var floorY: Float = .nan

    // MARK: - Public API

    /// Runs the full three-stage pipeline on one AR frame and returns the recommended
    /// steering direction. Must be called from DepthNavigator.queue only.
    func computeSteering(
        frame: ARFrame,
        currentHeadingSector: Int,
        targetSector: Int = 0
    ) -> SteeringResult {
        let t0       = CACurrentMediaTime()
        let grid     = projectToBEV(frame: frame)
        let polar    = buildPolarHistogram(grid: grid)
        let mask     = maskedHistogram(polar: polar, previous: previousMask)
        previousMask = mask
        let valleys  = findCandidateValleys(mask: mask, polar: polar)
        let result   = selectSteering(
            candidates:     valleys,
            targetSector:   targetSector,
            currentSector:  currentHeadingSector,
            previousSector: previousSteeringSector
        )
        previousSteeringSector = sectorIndex(for: result.angle)

        let pipelineMs = (CACurrentMediaTime() - t0) * 1_000
        NavigationSessionLogger.shared.logFrame(steering: result, pipelineMs: pipelineMs)
        if pipelineMs > 8 {
            AppLogger.navigation.warning("VFH pipeline \(String(format: "%.1f", pipelineMs)) ms (target ≤ 8 ms)")
        }
        return result
    }

    /// Update the floor reference when ARKit detects or refines a horizontal plane anchor.
    func calibrateFloor(planeAnchor: ARPlaneAnchor) {
        guard planeAnchor.alignment == .horizontal else { return }
        floorY = planeAnchor.transform.columns.3.y
    }

    /// Reset all accumulated per-session state. Call when a navigation session ends.
    func reset() {
        previousMask           = Array(repeating: false, count: PolarHistogram.sectorCount)
        previousSteeringSector = 0
        floorY                 = .nan
    }

    // MARK: - Stage 1: Bird's-Eye-View Occupancy Grid

    private func projectToBEV(frame: ARFrame) -> BEVGrid {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            return .empty
        }

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
        guard w > 0, h > 0, let depthBase = CVPixelBufferGetBaseAddress(depthMap) else {
            return .empty
        }

        let depthBuf = depthBase.bindMemory(to: Float32.self, capacity: w * h)

        var confBuf: UnsafeMutablePointer<UInt8>?
        if let c = confMap, let base = CVPixelBufferGetBaseAddress(c) {
            confBuf = base.bindMemory(to: UInt8.self, capacity: w * h)
        }

        let camToWorld = frame.camera.transform
        let intrinsics = frame.camera.intrinsics

        // simd_float3x3 is column-major: [col][row]
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]

        let userX = camToWorld.columns.3.x
        let userZ = camToWorld.columns.3.z

        // Use calibrated floor or estimate from camera height (phone held ~1.2 m above ground)
        let cameraY      = camToWorld.columns.3.y
        let effectiveFloor: Float = floorY.isNaN ? (cameraY - 1.2) : floorY

        var cells = Array(repeating: Array(repeating: false, count: BEVGrid.gridSize),
                          count: BEVGrid.gridSize)

        // Downsample to every 4th pixel → ~3 072 projections per 256 × 192 frame
        for v in stride(from: 0, to: h, by: 4) {
            for u in stride(from: 0, to: w, by: 4) {
                let idx = v * w + u

                // ARConfidenceLevel: 0 = low, 1 = medium, 2 = high — require at least medium
                if let conf = confBuf, conf[idx] < 1 { continue }

                let d = Float(depthBuf[idx])
                guard d.isFinite, d >= 0.2, d <= BEVGrid.maxRange else { continue }

                // Pixel → camera-space 3-D point; ARKit camera faces −Z
                let xCam = (Float(u) - cx) * d / fx
                let yCam = (Float(v) - cy) * d / fy
                let pCam = SIMD4<Float>(xCam, yCam, -d, 1)

                // Camera-space → world-space
                let pWorld = camToWorld * pCam

                // Height filter: keep only points between curb/shin height and head height
                let relH = pWorld.y - effectiveFloor
                guard relH >= BEVGrid.minHeight, relH <= BEVGrid.maxHeight else { continue }

                // World (X, Z) → grid cell; user is always at grid centre
                let gx = Int((pWorld.x - userX) / BEVGrid.cellSize) + BEVGrid.gridSize / 2
                let gz = Int((pWorld.z - userZ) / BEVGrid.cellSize) + BEVGrid.gridSize / 2

                guard (0..<BEVGrid.gridSize).contains(gx),
                      (0..<BEVGrid.gridSize).contains(gz) else { continue }

                cells[gz][gx] = true
            }
        }

        return BEVGrid(cells: cells)
    }

    // MARK: - Stage 2: Polar Obstacle Histogram

    private func buildPolarHistogram(grid: BEVGrid) -> PolarHistogram {
        let center = BEVGrid.gridSize / 2
        var weightedOccupancy = [Float](repeating: 0, count: PolarHistogram.sectorCount)
        var totalCells        = [Int](repeating: 0,   count: PolarHistogram.sectorCount)

        for gz in 0..<BEVGrid.gridSize {
            for gx in 0..<BEVGrid.gridSize {
                let dx   = Float(gx - center)
                let dz   = Float(gz - center)
                let dist = sqrt(dx * dx + dz * dz) * BEVGrid.cellSize
                // Ignore self-proximity noise and far-range unreliable readings
                guard dist >= 0.3, dist <= 4.0 else { continue }

                // atan2(dx, -dz): forward = −Z in ARKit → maps to sector 0 at 0 radians
                let rawAngle        = atan2(dx, -dz)
                let normalizedAngle = rawAngle < 0 ? rawAngle + 2 * Float.pi : rawAngle
                let sector          = min(
                    Int(normalizedAngle / PolarHistogram.sectorAngle),
                    PolarHistogram.sectorCount - 1
                )

                totalCells[sector] += 1
                if grid.cells[gz][gx] {
                    // Closer obstacles contribute more weight (inverse-distance weighting)
                    weightedOccupancy[sector] += 1.0 / max(0.3, dist)
                }
            }
        }

        // Normalise: density = weighted occupied / total cells in sector
        var densities = [Float](repeating: 0, count: PolarHistogram.sectorCount)
        for s in 0..<PolarHistogram.sectorCount where totalCells[s] > 0 {
            densities[s] = weightedOccupancy[s] / Float(totalCells[s])
        }

        return PolarHistogram(densities: densities)
    }

    // MARK: - Stage 3: VFH+ Steering Selection

    /// Converts the continuous density histogram to a binary blocked/free mask.
    /// Hysteresis prevents sector states from flickering at the threshold boundary.
    private func maskedHistogram(polar: PolarHistogram, previous: [Bool]) -> [Bool] {
        let upper: Float = 0.35
        let lower: Float = 0.15
        return polar.densities.enumerated().map { i, density in
            if density > upper { return true  }  // clearly blocked
            if density < lower { return false }  // clearly free
            return previous[i]                   // hysteresis: retain last known state
        }
    }

    /// Scans the circular binary mask for consecutive free-sector runs ≥ 2 wide.
    private func findCandidateValleys(mask: [Bool], polar: PolarHistogram) -> [CandidateValley] {
        let count   = PolarHistogram.sectorCount
        var valleys = [CandidateValley]()
        var visited = Set<Int>()

        for start in 0..<count {
            guard !mask[start], !visited.contains(start) else { continue }

            // Expand run circularly; cap at full circle to prevent infinite loops
            var runLen = 0
            while runLen < count, !mask[(start + runLen) % count] {
                visited.insert((start + runLen) % count)
                runLen += 1
            }
            guard runLen >= 2 else { continue }

            let centerSector = (start + runLen / 2) % count
            let centerAngle  = Float(centerSector) * PolarHistogram.sectorAngle

            // Clearance estimate: low average density in the valley → more free space
            var densitySum = Float(0)
            for k in 0..<runLen {
                densitySum += polar.densities[(start + k) % count]
            }
            let avgDensity = densitySum / Float(runLen)
            let clearance  = (1.0 - min(avgDensity, 1.0)) * BEVGrid.maxRange

            valleys.append(CandidateValley(
                startSector: start,
                endSector:   (start + runLen - 1) % count,
                centerAngle: centerAngle,
                width:       runLen,
                clearance:   clearance
            ))
        }
        return valleys
    }

    /// Picks the lowest-cost candidate valley. When no valley exists, returns .none.
    private func selectSteering(
        candidates:     [CandidateValley],
        targetSector:   Int,
        currentSector:  Int,
        previousSector: Int
    ) -> SteeringResult {
        guard !candidates.isEmpty else {
            return SteeringResult(angle: 0, clearance: 0, confidence: 0, direction: .none, valleyCount: 0)
        }

        let best = candidates.min { a, b in
            vfhCost(a, target: targetSector, current: currentSector, previous: previousSector) <
            vfhCost(b, target: targetSector, current: currentSector, previous: previousSector)
        }!

        return SteeringResult(
            angle:       best.centerAngle,
            clearance:   best.clearance,
            confidence:  Float(best.width) / Float(PolarHistogram.sectorCount),
            direction:   clearDirection(from: best.centerAngle),
            valleyCount: candidates.count
        )
    }

    /// VFH+ cost function (lower = better direction to walk toward).
    ///
    ///   cost = 5 × Δ(valley, target)    — pull toward destination (or straight ahead)
    ///        + 2 × Δ(valley, current)   — prefer current walking direction
    ///        + 3 × Δ(valley, previous)  — smoothness: penalise sudden direction reversals
    ///        + 1 × max(0, 4 − width)    — penalty for narrow valleys (< 40°)
    private func vfhCost(
        _ valley: CandidateValley,
        target:   Int,
        current:  Int,
        previous: Int
    ) -> Float {
        let n      = PolarHistogram.sectorCount
        let center = sectorIndex(for: valley.centerAngle)

        func angDist(_ a: Int, _ b: Int) -> Float {
            Float(min(abs(a - b), n - abs(a - b)))
        }

        return 5.0 * angDist(center, target)
             + 2.0 * angDist(center, current)
             + 3.0 * angDist(center, previous)
             + 1.0 * Float(max(0, 4 - valley.width))
    }

    // MARK: - Helpers

    private func sectorIndex(for angle: Float) -> Int {
        let normalized = angle < 0 ? angle + 2 * Float.pi : angle
        return min(Int(normalized / PolarHistogram.sectorAngle), PolarHistogram.sectorCount - 1)
    }

    /// Maps a continuous steering angle to the backward-compatible ClearDirection enum.
    private func clearDirection(from angle: Float) -> ClearDirection {
        let normalized = angle < 0 ? angle + 2 * Float.pi : angle
        let degrees    = normalized * 180.0 / Float.pi
        if degrees < 30 || degrees > 330 { return .center }
        if degrees <= 180               { return .right  }
        return .left
    }
}
