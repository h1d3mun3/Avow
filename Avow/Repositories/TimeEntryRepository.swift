import Foundation

protocol TimeEntryRepository {
    func update(_ entry: TimeEntry, start: Date, end: Date?) throws
    func delete(_ entry: TimeEntry) throws
}
