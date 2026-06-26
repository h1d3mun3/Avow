import Foundation
import Observation

/// Whether summary durations are rounded to whole minutes for display.
///
/// Off by default, so existing behaviour is unchanged until the user opts in.
/// The setting only affects how durations are *displayed* in summaries — the
/// stored start/end times keep their full precision, so toggling this is
/// non-destructive and reversible. Persisted in UserDefaults.
@MainActor
@Observable
final class TimeRoundingSettings {
    var roundToMinute: Bool {
        didSet {
            guard roundToMinute != oldValue else { return }
            UserDefaults.standard.set(roundToMinute, forKey: Self.key)
        }
    }

    private static let key = "summaryRounding.roundToMinute"

    init() {
        roundToMinute = UserDefaults.standard.bool(forKey: Self.key)
    }

    /// Rounds a standalone summary total when the option is enabled.
    func display(_ duration: TimeInterval) -> TimeInterval {
        roundToMinute ? MinuteRounding.nearest(duration) : duration
    }

    /// Rounds an ordered list of a perspective's durations so the parts sum to the
    /// rounded total when the option is enabled, otherwise returns them unchanged.
    func display(_ durations: [TimeInterval]) -> [TimeInterval] {
        roundToMinute ? MinuteRounding.cumulative(durations) : durations
    }
}
