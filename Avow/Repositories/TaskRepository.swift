import Foundation

protocol TaskRepository {
    func add(named name: String, to project: Project) throws
    func updateStatus(_ task: Task, to status: TaskStatus) throws
    func rename(_ task: Task, to name: String) throws
    func delete(_ task: Task) throws
}
