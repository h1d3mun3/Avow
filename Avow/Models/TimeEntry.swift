import Foundation
import SwiftData

@Model
final class TimeEntry {
    @Attribute(.unique)
    var id: UUID

    var startDate: Date
    var endDate: Date?
    var createdAt: Date

    var task: Task?

    var isRunning: Bool {
        endDate == nil
    }

    var duration: TimeInterval {
        duration(asOf: .now)
    }

    func duration(asOf reference: Date) -> TimeInterval {
        (endDate ?? reference).timeIntervalSince(startDate)
    }

    init(
        startDate: Date = .now,
        task: Task
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.createdAt = .now
        self.task = task
    }

    func stop() {
        endDate = .now
    }
}
