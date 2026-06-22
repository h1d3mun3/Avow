import Foundation

protocol FacetRepository {
    /// All facets, sorted by name.
    func allFacetsSortedByName() throws -> [Facet]
    /// Returns the facet with this name, creating and persisting it if none exists.
    func findOrCreate(named name: String) throws -> Facet
    /// Renames the facet. No-op for an empty or unchanged name; throws if another facet already carries the name.
    func rename(_ facet: Facet, to name: String) throws
    /// Attaches the facet to the task (no-op if already attached).
    func attach(_ facet: Facet, to task: Task) throws
    /// Detaches the facet from the task (no-op if not attached).
    func detach(_ facet: Facet, from task: Task) throws
    /// Deletes the facet, removing it from every task that carries it.
    func delete(_ facet: Facet) throws
}

enum FacetRepositoryError: LocalizedError {
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "A facet named \"\(name)\" already exists."
        }
    }
}
