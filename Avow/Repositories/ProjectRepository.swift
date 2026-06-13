import Foundation

protocol ProjectRepository {
    func archive(_ project: Project) throws
    func unarchive(_ project: Project) throws
    func delete(_ project: Project) throws
    func rename(_ project: Project, to name: String) throws
    func reorder(_ projects: [Project]) throws
}
