import Foundation

protocol TaskRepository {
    @discardableResult
    func add(named name: String, to project: Project) throws -> Task
    func updateStatus(_ task: Task, to status: TaskStatus) throws
    func rename(_ task: Task, to name: String) throws
    /// Reassigns the task to another project. Takes an id because the caller is a
    /// drop handler, which only receives the dragged task's id. Returns false when
    /// no task carries the id or it already belongs to the project, so the drop can
    /// be refused rather than silently doing nothing.
    @discardableResult
    func move(taskWithID id: UUID, to project: Project) throws -> Bool
    func delete(_ task: Task) throws
}
