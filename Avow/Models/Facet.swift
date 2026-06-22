import Foundation
import SwiftData

/// A cross-cutting "kind of work" label used purely to aggregate time across tasks.
/// Orthogonal to Project: a task may carry several facets, and most tasks carry none.
@Model
final class Facet {
    @Attribute(.unique)
    var id: UUID

    @Attribute(.unique)
    var name: String
    var createdAt: Date

    @Relationship(inverse: \Task.facets)
    var tasks: [Task]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.tasks = []
    }
}
