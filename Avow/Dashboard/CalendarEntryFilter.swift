import Foundation

/// Narrows which time entries are visible in the Calendar tab. Each field is
/// `nil` when unfiltered — including projects/facets created later; a
/// non-nil value narrows down to a single project or facet.
struct CalendarEntryFilter: Equatable {
    var projectID: UUID?
    var facetID: UUID?

    static let all = CalendarEntryFilter()

    func includes(_ entry: TimeEntry) -> Bool {
        if let projectID, entry.task?.project?.id != projectID { return false }
        if let facetID, entry.task?.facets.contains(where: { $0.id == facetID }) != true { return false }
        return true
    }
}

extension Sequence where Element == TimeEntry {
    /// Entries matching `filter`'s project and facet selection.
    func filtered(by filter: CalendarEntryFilter) -> [TimeEntry] {
        guard filter.projectID != nil || filter.facetID != nil else { return Array(self) }
        return self.filter(filter.includes)
    }
}
