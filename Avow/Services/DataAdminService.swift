import Foundation
import SwiftData

struct DataAdminService {
    let context: ModelContext

    /// Deletes every time entry, task, and project.
    ///
    /// Deletes per-instance instead of `ModelContext.delete(model:)`: the batch variant is
    /// backed by an NSBatchDeleteRequest, which in-memory stores don't support (so it fails
    /// under tests). Children are removed before parents so cascade rules never act on
    /// already-deleted rows.
    /// Deletes everything. Pass `saving: false` to leave the deletions pending so a caller can
    /// commit them together with other work in a single transaction (used by a Replace import,
    /// which must be all-or-nothing).
    func deleteAllData(saving: Bool = true) throws {
        for entry in try context.fetch(FetchDescriptor<TimeEntry>()) {
            context.delete(entry)
        }
        for task in try context.fetch(FetchDescriptor<Task>()) {
            context.delete(task)
        }
        for project in try context.fetch(FetchDescriptor<Project>()) {
            context.delete(project)
        }
        // Facets are not cascade-deleted by tasks (the Task<->Facet relationship nullifies),
        // so remove them explicitly or a reset would leave orphaned rows behind — which then
        // collide with the unique-name constraint when a same-named facet is recreated.
        for facet in try context.fetch(FetchDescriptor<Facet>()) {
            context.delete(facet)
        }
        if saving {
            try context.save()
        }
    }
}
