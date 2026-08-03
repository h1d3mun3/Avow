import Foundation

struct ExportService {

    /// Escapes a field for RFC 4180 CSV: wraps in quotes and doubles any internal quote.
    static func csvEscape(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Builds the JSON backup. `facets` should be the full facet list so that standalone
    /// facets (not attached to any task) also survive; any facet reachable from a task is
    /// included automatically even if omitted from `facets`. Likewise `projectGroups` should be
    /// the full group list so that standalone groups (not attached to any project) also survive;
    /// any group reachable from a project is included automatically even if omitted here.
    func buildJSONData(
        from projects: [Project],
        facets: [Facet] = [],
        projectGroups: [ProjectGroup] = [],
        exportedAt: Date = .now
    ) throws -> Data {
        // Union of explicitly-passed facets and every facet attached to an exported task,
        // de-duplicated by id, so the Task<->Facet many-to-many can be rebuilt on import.
        var facetsByID: [UUID: Facet] = [:]
        for facet in facets { facetsByID[facet.id] = facet }
        for facet in projects.flatMap(\.tasks).flatMap(\.facets) { facetsByID[facet.id] = facet }
        let allFacets = facetsByID.values.sorted { $0.name < $1.name }

        // Same union approach for project groups, keyed against the Project<->ProjectGroup
        // many-to-many instead of Task<->Facet.
        var groupsByID: [UUID: ProjectGroup] = [:]
        for group in projectGroups { groupsByID[group.id] = group }
        for group in projects.flatMap(\.projectGroups) { groupsByID[group.id] = group }
        let allGroups = groupsByID.values.sorted { $0.name < $1.name }

        let schema = ExportSchema(
            version: ExportSchema.version,
            exportedAt: exportedAt,
            facets: allFacets.map { facet in
                ExportSchema.ExportFacet(
                    id: facet.id,
                    name: facet.name,
                    createdAt: facet.createdAt
                )
            },
            projectGroups: allGroups.map { group in
                ExportSchema.ExportProjectGroup(
                    id: group.id,
                    name: group.name,
                    createdAt: group.createdAt
                )
            },
            // Sort by the user's manual ordering and stable secondary keys so re-exporting
            // unchanged data produces identical output (SwiftData relationship arrays are unordered).
            projects: projects.sorted { $0.sortOrder < $1.sortOrder }.map { project in
                ExportSchema.ExportProject(
                    id: project.id,
                    name: project.name,
                    sortOrder: project.sortOrder,
                    isArchived: project.isArchived,
                    createdAt: project.createdAt,
                    updatedAt: project.updatedAt,
                    projectGroupIDs: project.projectGroups.map(\.id).sorted { $0.uuidString < $1.uuidString },
                    tasks: project.tasks.sorted { $0.createdAt < $1.createdAt }.map { task in
                        ExportSchema.ExportTask(
                            id: task.id,
                            name: task.name,
                            status: task.status.rawValue,
                            createdAt: task.createdAt,
                            updatedAt: task.updatedAt,
                            facetIDs: task.facets.map(\.id).sorted { $0.uuidString < $1.uuidString },
                            timeEntries: task.timeEntries.sorted { $0.startDate < $1.startDate }.map { entry in
                                ExportSchema.ExportTimeEntry(
                                    id: entry.id,
                                    startDate: entry.startDate,
                                    endDate: entry.endDate,
                                    createdAt: entry.createdAt
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
        // RFC 4180 row terminator is CRLF, which keeps a quoted field's embedded LF
        // unambiguous from a record boundary.
        let terminator = "\r\n"
        var csv = "project,task,facets,start,end,duration_seconds,project_id,task_id,entry_id" + terminator

        let entries = projects
            .flatMap(\.tasks)
            .flatMap(\.timeEntries)
            .sorted { $0.startDate < $1.startDate }

        for entry in entries {
            let project = entry.task?.project?.name ?? ""
            let task = entry.task?.name ?? ""
            let facets = (entry.task?.facets ?? [])
                .map(\.name)
                .sorted()
                .joined(separator: "; ")
            let start = isoFormatter.string(from: entry.startDate)
            let end = entry.endDate.map { isoFormatter.string(from: $0) } ?? ""
            // Leave duration empty for a running entry (consistent with the empty end column)
            // and derive it from endDate — never .now — so exports are deterministic.
            let duration = entry.endDate.map { String(Int($0.timeIntervalSince(entry.startDate))) } ?? ""
            let projectID = entry.task?.project?.id.uuidString ?? ""
            let taskID = entry.task?.id.uuidString ?? ""
            let entryID = entry.id.uuidString
            // start/end (ISO8601), ids (UUID) and duration (Int) contain no comma, quote or
            // newline, so only the free-text name/facet columns need escaping.
            let fields = [
                Self.csvEscape(project),
                Self.csvEscape(task),
                Self.csvEscape(facets),
                start,
                end,
                duration,
                projectID,
                taskID,
                entryID,
            ]
            csv += fields.joined(separator: ",") + terminator
        }
        return csv
    }
}
