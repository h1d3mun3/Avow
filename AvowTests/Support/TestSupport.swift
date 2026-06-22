import Foundation
import SwiftData
@testable import Avow

/// A fresh in-memory SwiftData context for tests.
func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Project.self, Task.self, TimeEntry.self, Facet.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    return ModelContext(container)
}

/// A controllable clock: fire the scheduled action manually via advance(), and a settable now().
final class ManualClock: AppClock {
    private(set) var scheduledAction: (() -> Void)?
    var nowDate: Date

    init(now: Date = .now) {
        nowDate = now
    }

    func now() -> Date { nowDate }

    func scheduleRepeating(interval: TimeInterval, action: @escaping () -> Void) -> ClockToken {
        scheduledAction = action
        return ClockToken { [weak self] in self?.scheduledAction = nil }
    }

    func advance() {
        scheduledAction?()
    }
}
