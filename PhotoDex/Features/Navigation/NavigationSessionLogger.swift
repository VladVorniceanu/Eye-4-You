//
//  NavigationSessionLogger.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 6/3/26.
//

import Foundation

/// Collects per-session navigation metrics for dissertation evidence.
///
/// Records: frames processed, VFH pipeline latency, clearance samples,
/// near-miss events (clearance < 0.5 m), and TTS fired vs. suppressed counts.
///
/// Thread-safe: all methods may be called from any queue.
final class NavigationSessionLogger {

    static let shared = NavigationSessionLogger()
    private init() {}

    private let lock = NSLock()

    private var _framesProcessed:  Int    = 0
    private var _nearMissCount:    Int    = 0
    private var _ttsFireCount:     Int    = 0
    private var _ttsSuppressCount: Int    = 0
    private var _sessionStart:     Date?
    private var _latencySamples:   [Double] = []
    private var _clearanceSamples: [Float]  = []

    // Rolling window — ~50 s at 12 Hz
    private static let maxSamples = 600

    // MARK: - Public read-only metrics

    var framesProcessed:  Int { lock.lock(); defer { lock.unlock() }; return _framesProcessed  }
    var nearMissCount:    Int { lock.lock(); defer { lock.unlock() }; return _nearMissCount    }
    var ttsFireCount:     Int { lock.lock(); defer { lock.unlock() }; return _ttsFireCount     }
    var ttsSuppressCount: Int { lock.lock(); defer { lock.unlock() }; return _ttsSuppressCount }

    var averageLatencyMs: Double {
        lock.lock(); defer { lock.unlock() }
        guard !_latencySamples.isEmpty else { return 0 }
        return _latencySamples.reduce(0, +) / Double(_latencySamples.count)
    }

    var maxLatencyMs: Double {
        lock.lock(); defer { lock.unlock() }
        return _latencySamples.max() ?? 0
    }

    var averageClearance: Float {
        lock.lock(); defer { lock.unlock() }
        guard !_clearanceSamples.isEmpty else { return 0 }
        return _clearanceSamples.reduce(0, +) / Float(_clearanceSamples.count)
    }

    /// Fraction of YOLO alert cycles that were fully suppressed by PathAwareFilter.
    var suppressionRate: Double {
        lock.lock(); defer { lock.unlock() }
        let total = _ttsFireCount + _ttsSuppressCount
        return total > 0 ? Double(_ttsSuppressCount) / Double(total) : 0
    }

    // MARK: - Recording

    func startSession() {
        lock.lock()
        _framesProcessed  = 0
        _nearMissCount    = 0
        _ttsFireCount     = 0
        _ttsSuppressCount = 0
        _latencySamples   = []
        _clearanceSamples = []
        _sessionStart     = Date()
        lock.unlock()
    }

    /// Called once per processed AR frame from PathPlanner (on DepthNavigator.queue).
    func logFrame(steering: SteeringResult, pipelineMs: Double) {
        lock.lock()
        _framesProcessed += 1
        // Near-miss: best available direction has clearance < 0.5 m (not counting all-blocked)
        if steering.clearance < 0.5 && steering.direction != .none { _nearMissCount += 1 }
        _clearanceSamples.append(steering.clearance)
        _latencySamples.append(pipelineMs)
        if _clearanceSamples.count > Self.maxSamples { _clearanceSamples.removeFirst() }
        if _latencySamples.count   > Self.maxSamples { _latencySamples.removeFirst()   }
        lock.unlock()
    }

    /// Called by PathAwareFilter once per YOLO cycle: fired = at least one alert passed.
    func logTTSEvent(suppressed: Bool) {
        lock.lock()
        if suppressed { _ttsSuppressCount += 1 }
        else          { _ttsFireCount     += 1 }
        lock.unlock()
    }

    func reset() { startSession() }

    // MARK: - Export

    /// Returns a formatted summary suitable for dissertation reporting.
    func exportSummary() -> String {
        lock.lock()
        defer { lock.unlock() }

        let duration = _sessionStart.map { Date().timeIntervalSince($0) } ?? 0
        let total    = _ttsFireCount + _ttsSuppressCount
        let suppPct  = total > 0
            ? String(format: "%.0f%%", Double(_ttsSuppressCount) / Double(total) * 100)
            : "—"
        let avgClr   = _clearanceSamples.isEmpty ? "—"
            : String(format: "%.2f m", _clearanceSamples.reduce(0, +) / Float(_clearanceSamples.count))
        let avgLat   = _latencySamples.isEmpty ? "—"
            : String(format: "%.1f ms", _latencySamples.reduce(0, +) / Double(_latencySamples.count))
        let maxLat   = _latencySamples.isEmpty ? "—"
            : String(format: "%.1f ms", _latencySamples.max()!)

        return """
        Navigation Session Summary
        ─────────────────────────
        Duration:          \(String(format: "%.0f", duration)) s
        Frames processed:  \(_framesProcessed)
        Avg clearance:     \(avgClr)
        Near-miss events:  \(_nearMissCount)
        TTS fired:         \(_ttsFireCount)
        TTS suppressed:    \(_ttsSuppressCount) (\(suppPct))
        Avg VFH pipeline:  \(avgLat)
        Max VFH pipeline:  \(maxLat)
        """
    }
}
