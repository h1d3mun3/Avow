import Foundation

/// Display-time rounding of durations to whole minutes.
///
/// Summaries must reconcile: within a single view ("perspective") the rounded
/// parts must sum exactly to that perspective's rounded total. Rounding each
/// item independently fails this — the per-item errors accumulate, so e.g. a
/// 20-minute and a 40-minute entry could total 59 or 61 instead of 60.
///
/// Instead we round *cumulatively*: each item's displayed value is the difference
/// between the rounded running total before and after it. This guarantees the
/// parts always sum to `nearest(total)`, with the total never drifting more than
/// 30 seconds from reality. The trade-off is that an item's rounded value depends
/// on its position in the list — intrinsic to keeping parts and total in agreement.
enum MinuteRounding {
    static let minute: TimeInterval = 60

    /// Rounds a standalone duration to the nearest whole minute.
    static func nearest(_ duration: TimeInterval) -> TimeInterval {
        (duration / minute).rounded() * minute
    }

    /// Cumulative rounding for a perspective's ordered durations.
    ///
    /// Returns whole-minute values, aligned with the input order, that sum exactly
    /// to `nearest(durations.reduce(+:))`. Inputs are assumed non-negative (durations
    /// never decrease the running total), so every result is non-negative too.
    static func cumulative(_ durations: [TimeInterval]) -> [TimeInterval] {
        var result: [TimeInterval] = []
        result.reserveCapacity(durations.count)
        var runningRaw: TimeInterval = 0
        var roundedSoFar: TimeInterval = 0
        for duration in durations {
            runningRaw += duration
            let roundedRunning = nearest(runningRaw)
            result.append(roundedRunning - roundedSoFar)
            roundedSoFar = roundedRunning
        }
        return result
    }
}
