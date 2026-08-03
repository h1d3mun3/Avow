import Foundation
import SwiftData

/// A cross-cutting label used to bundle multiple Projects for combined time reporting.
/// Orthogonal to Facet (which labels Tasks): a project may belong to several groups, most belong to none.
@Model
final class ProjectGroup {
    @Attribute(.unique)
    var id: UUID

    @Attribute(.unique)
    var name: String
    var createdAt: Date

    @Relationship(inverse: \Project.projectGroups)
    var projects: [Project]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.projects = []
    }
}
