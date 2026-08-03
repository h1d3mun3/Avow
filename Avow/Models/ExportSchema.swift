import Foundation

struct ExportSchema: Codable {
    /// Bumped to 2 when the schema gained facets and the previously dropped
    /// project/task/entry fields (sortOrder, isArchived, updatedAt, createdAt).
    /// Bumped to 3 when the schema gained project groups.
    static let version = 3

    let version: Int
    let exportedAt: Date
    let facets: [ExportFacet]
    let projectGroups: [ExportProjectGroup]
    let projects: [ExportProject]

    struct ExportFacet: Codable {
        let id: UUID
        let name: String
        let createdAt: Date
    }

    struct ExportProjectGroup: Codable {
        let id: UUID
        let name: String
        let createdAt: Date
    }

    struct ExportProject: Codable {
        let id: UUID
        let name: String
        let sortOrder: Int
        let isArchived: Bool
        let createdAt: Date
        let updatedAt: Date
        /// References into the top-level `projectGroups` list (the Project<->ProjectGroup many-to-many).
        let projectGroupIDs: [UUID]
        let tasks: [ExportTask]
    }

    struct ExportTask: Codable {
        let id: UUID
        let name: String
        let status: String
        let createdAt: Date
        let updatedAt: Date
        /// References into the top-level `facets` list (the Task<->Facet many-to-many).
        let facetIDs: [UUID]
        let timeEntries: [ExportTimeEntry]
    }

    struct ExportTimeEntry: Codable {
        let id: UUID
        let startDate: Date
        let endDate: Date?
        let createdAt: Date
    }
}
