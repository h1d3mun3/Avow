import Foundation

protocol TimeEntryRepository {
    func start(task: Task) throws -> TimeEntry
    /// Creates an already-completed entry for time that wasn't tracked live.
    func add(task: Task, start: Date, end: Date) throws -> TimeEntry
    func stop(_ entry: TimeEntry) throws
    func fetchRunning() throws -> TimeEntry?
    func update(_ entry: TimeEntry, start: Date, end: Date?) throws
    func delete(_ entry: TimeEntry) throws
}

enum TimeEntryRepositoryError: LocalizedError {
    case endBeforeStart

    var errorDescription: String? {
        switch self {
        case .endBeforeStart:
            return "The end time must be on or after the start time."
        }
    }
}
