import Foundation
import SwiftData

/// Restores a JSON backup produced by `ExportService` — a faithful round trip of every
/// Project/Task/TimeEntry/Facet. (CSV is export-only, for spreadsheet analysis, so there is
/// no CSV importer.)
///
/// Each import runs inside a single `ModelContext` transaction, so a failure — including a
/// Replace that wipes existing data first — rolls back entirely rather than leaving a
/// half-written store.
struct ImportService {

    enum Mode {
        /// Keep existing data; update rows whose id matches, insert the rest.
        case merge
        /// Delete everything first, then insert the file's contents (atomic with the insert).
        case replace
    }

    enum ImportError: LocalizedError {
        case unsupportedVersion(Int)
        case invalidFile

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "This file was made by a newer version of Avow (export version \(version)) and can't be imported."
            case .invalidFile:
                return "The file couldn't be read. Make sure it's a valid Avow JSON export."
            }
        }
    }

    private struct VersionProbe: Codable { let version: Int }

    let context: ModelContext

    func importJSON(from url: URL, mode: Mode) throws {
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw ImportError.invalidFile }
        try importJSON(data, mode: mode)
    }

    func importJSON(_ data: Data, mode: Mode) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let schema: ExportSchema
        do {
            schema = try decoder.decode(ExportSchema.self, from: data)
        } catch {
            // A versioned-but-older/foreign envelope gets a clear version error; anything else
            // is simply not a recognisable export file.
            if let probe = try? decoder.decode(VersionProbe.self, from: data) {
                throw ImportError.unsupportedVersion(probe.version)
            }
            throw ImportError.invalidFile
        }
        guard schema.version <= ExportSchema.version else {
            throw ImportError.unsupportedVersion(schema.version)
        }

        try context.transaction {
            try applyJSON(schema, mode: mode)
        }
    }

    private func applyJSON(_ schema: ExportSchema, mode: Mode) throws {
        if mode == .replace {
            try DataAdminService(context: context).deleteAllData(saving: false)
        }

        // In replace mode the store is (pending) empty, so start from empty lookups and insert
        // everything fresh; in merge mode reconcile against what already exists.
        var facetsByID = mode == .replace ? [:] : try fetchByID(Facet.self, id: \.id)
        var facetsByName = Dictionary(facetsByID.values.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        // Resolve each exported facet to a model (existing by id, then by unique name, else new),
        // keyed by the id used in the file so tasks can wire up their facetIDs.
        var resolvedFacets: [UUID: Facet] = [:]
        for exported in schema.facets {
            let facet: Facet
            if let existing = facetsByID[exported.id] {
                facet = existing
            } else if let existing = facetsByName[exported.name] {
                facet = existing
            } else {
                facet = Facet(name: exported.name)
                facet.id = exported.id
                context.insert(facet)
            }
            // Reconcile mutable fields on every branch so a renamed facet round-trips. Keep the
            // name index in sync (drop the stale name) so a later same-name lookup still resolves.
            if facet.name != exported.name {
                facetsByName[facet.name] = nil
            }
            facet.name = exported.name
            facet.createdAt = exported.createdAt
            facetsByID[facet.id] = facet
            facetsByName[facet.name] = facet
            resolvedFacets[exported.id] = facet
        }

        var projectsByID = mode == .replace ? [:] : try fetchByID(Project.self, id: \.id)
        var tasksByID = mode == .replace ? [:] : try fetchByID(Task.self, id: \.id)
        var entriesByID = mode == .replace ? [:] : try fetchByID(TimeEntry.self, id: \.id)

        for exportedProject in schema.projects {
            let project: Project
            if let existing = projectsByID[exportedProject.id] {
                project = existing
            } else {
                project = Project(name: exportedProject.name)
                project.id = exportedProject.id
                context.insert(project)
                projectsByID[project.id] = project
            }
            project.name = exportedProject.name
            project.sortOrder = exportedProject.sortOrder
            project.isArchived = exportedProject.isArchived
            project.createdAt = exportedProject.createdAt
            project.updatedAt = exportedProject.updatedAt

            for exportedTask in exportedProject.tasks {
                let task: Task
                if let existing = tasksByID[exportedTask.id] {
                    task = existing
                } else {
                    task = Task(name: exportedTask.name, project: project)
                    task.id = exportedTask.id
                    context.insert(task)
                    tasksByID[task.id] = task
                }
                task.name = exportedTask.name
                task.status = TaskStatus(rawValue: exportedTask.status) ?? .active
                task.createdAt = exportedTask.createdAt
                task.updatedAt = exportedTask.updatedAt
                task.project = project
                // Fall back to a store facet by id if the file references one it didn't list.
                task.facets = exportedTask.facetIDs.compactMap { resolvedFacets[$0] ?? facetsByID[$0] }

                for exportedEntry in exportedTask.timeEntries {
                    let entry: TimeEntry
                    if let existing = entriesByID[exportedEntry.id] {
                        entry = existing
                    } else {
                        entry = TimeEntry(startDate: exportedEntry.startDate, task: task)
                        entry.id = exportedEntry.id
                        context.insert(entry)
                        entriesByID[entry.id] = entry
                    }
                    entry.startDate = exportedEntry.startDate
                    entry.endDate = exportedEntry.endDate
                    entry.createdAt = exportedEntry.createdAt
                    entry.task = task
                }
            }
        }
    }

    // MARK: - Helpers

    private func fetchByID<M: PersistentModel>(_ type: M.Type, id: KeyPath<M, UUID>) throws -> [UUID: M] {
        var result: [UUID: M] = [:]
        for model in try context.fetch(FetchDescriptor<M>()) {
            result[model[keyPath: id]] = model
        }
        return result
    }
}
