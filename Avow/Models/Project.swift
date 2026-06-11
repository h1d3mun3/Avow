import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique)
    var id: UUID

    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Task.project)
    var tasks: [Task]

    init(
        name: String,
        colorHex: String
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
        self.updatedAt = .now
        self.tasks = []
    }
}
