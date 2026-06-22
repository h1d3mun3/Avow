import Foundation

/// Per-project time breakdown for a single day's entries.
struct DayBreakdown {
    let total: TimeInterval
    let items: [(name: String, duration: TimeInterval, fraction: Double)]
    init(entries: [TimeEntry]) {
        let total = entries.totalDuration
        var groups: [String: TimeInterval] = [:]
        for entry in entries { groups[entry.task?.project?.name ?? "—", default: 0] += entry.duration }
        self.total = total
        self.items = groups
            .map { (name: $0.key, duration: $0.value, fraction: total > 0 ? $0.value / total : 0) }
            .sorted { $0.duration > $1.duration }
    }
}
