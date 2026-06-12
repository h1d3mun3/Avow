import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique)
    var id: UUID

    var name: String
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Task.project)
    var tasks: [Task]

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.isArchived = false
        self.createdAt = .now
        self.updatedAt = .now
        self.tasks = []
    }
}
