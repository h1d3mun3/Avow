import Foundation
import SwiftData

struct DataAdminService {
    let context: ModelContext

    /// Deletes everything. Order is load-bearing: modelContext.delete(model:) ignores cascade rules,
    /// so children must be removed before parents.
    func deleteAllData() throws {
        try context.delete(model: TimeEntry.self)
        try context.delete(model: Task.self)
        try context.delete(model: Project.self)
        try context.save()
    }
}
