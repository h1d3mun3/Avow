import Foundation
import SwiftData

enum TaskStatus: String, Codable {
    case active
    case completed
}

@Model
final class Task {
    @Attribute(.unique)
    var id: UUID

    var name: String
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
    var timeEntries: [TimeEntry]

    init(
        name: String,
        project: Project
    ) {
        self.id = UUID()
        self.name = name
        self.status = .active
        self.createdAt = .now
        self.updatedAt = .now
        self.project = project
        self.timeEntries = []
    }
}
