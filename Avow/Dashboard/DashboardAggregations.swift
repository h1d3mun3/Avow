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

/// Groups entries by their task (nil-task entries collapse into one group), sorted by task name.
func groupEntriesByTask(_ entries: [TimeEntry]) -> [(task: Task?, entries: [TimeEntry])] {
    var groups: [UUID?: [TimeEntry]] = [:]
    for entry in entries { groups[entry.task?.id, default: []].append(entry) }
    return groups
        .map { (task: $0.value.first?.task, entries: $0.value) }
        .sorted { ($0.task?.name ?? "") < ($1.task?.name ?? "") }
}
