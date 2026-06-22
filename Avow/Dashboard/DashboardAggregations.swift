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

/// Per-facet time totals for a day's entries, sorted by duration descending.
///
/// A task may carry several facets, so an entry's duration is counted toward each of
/// its task's facets — totals may therefore exceed the day total, since each facet
/// answers an independent "how much time on X?" question. Entries whose task has no
/// facet are omitted (unfaceted time is intentionally not surfaced).
struct FacetBreakdown {
    let items: [(name: String, duration: TimeInterval)]
    init(entries: [TimeEntry]) {
        var totals: [UUID: (name: String, duration: TimeInterval)] = [:]
        for entry in entries {
            guard let facets = entry.task?.facets, !facets.isEmpty else { continue }
            for facet in facets {
                totals[facet.id, default: (name: facet.name, duration: 0)].duration += entry.duration
            }
        }
        self.items = totals.values
            .map { (name: $0.name, duration: $0.duration) }
            .sorted { $0.duration > $1.duration }
    }
}
