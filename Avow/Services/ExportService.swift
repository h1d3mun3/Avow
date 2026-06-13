import Foundation

struct ExportService {

    /// Escapes a field for RFC 4180 CSV: wraps in quotes and doubles any internal quote.
    static func csvEscape(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func buildJSONData(from projects: [Project], exportedAt: Date = .now) throws -> Data {
        let schema = ExportSchema(
            version: ExportSchema.version,
            exportedAt: exportedAt,
            projects: projects.map { project in
                ExportSchema.ExportProject(
                    id: project.id,
                    name: project.name,
                    createdAt: project.createdAt,
                    tasks: project.tasks.map { task in
                        ExportSchema.ExportTask(
                            id: task.id,
                            name: task.name,
                            status: task.status.rawValue,
                            createdAt: task.createdAt,
                            timeEntries: task.timeEntries.map { entry in
                                ExportSchema.ExportTimeEntry(
                                    id: entry.id,
                                    startDate: entry.startDate,
                                    endDate: entry.endDate
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(schema)
    }

    func buildCSVString(from projects: [Project]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        var csv = "project,task,start,end,duration_seconds\n"

        let entries = projects
            .flatMap(\.tasks)
            .flatMap(\.timeEntries)
            .sorted { $0.startDate < $1.startDate }

        for entry in entries {
            let project = entry.task?.project?.name ?? ""
            let task = entry.task?.name ?? ""
            let start = isoFormatter.string(from: entry.startDate)
            let end = entry.endDate.map { isoFormatter.string(from: $0) } ?? ""
            let duration = Int(entry.duration)
            csv += "\(Self.csvEscape(project)),\(Self.csvEscape(task)),\(start),\(end),\(duration)\n"
        }
        return csv
    }
}
