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
    func deleteAllData() throws {
        for entry in try context.fetch(FetchDescriptor<TimeEntry>()) {
            context.delete(entry)
        }
        for task in try context.fetch(FetchDescriptor<Task>()) {
            context.delete(task)
        }
        for project in try context.fetch(FetchDescriptor<Project>()) {
            context.delete(project)
        }
        try context.save()
    }
}
