import Foundation

struct ExportSchema: Codable {
    static let version = 1

    let version: Int
    let exportedAt: Date
    let projects: [ExportProject]

    struct ExportProject: Codable {
        let id: UUID
        let name: String
        let colorHex: String
        let createdAt: Date
        let tasks: [ExportTask]
    }

    struct ExportTask: Codable {
        let id: UUID
        let name: String
        let status: String
        let createdAt: Date
        let timeEntries: [ExportTimeEntry]
    }

    struct ExportTimeEntry: Codable {
        let id: UUID
        let startDate: Date
        let endDate: Date?
    }
}
