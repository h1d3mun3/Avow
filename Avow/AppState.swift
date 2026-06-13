import Foundation
import SwiftData

@Observable
final class AppState {
    /// The currently running time entry, if any.
    var activeEntry: TimeEntry?

    /// Incremented every second while tracking, to trigger SwiftUI updates.
    var tick: UInt64 = 0

    private let clock: any AppClock
    private var clockToken: ClockToken?

    var isTracking: Bool {
        activeEntry != nil
    }

    init(clock: any AppClock = SystemClock()) {
        self.clock = clock
    }

    // MARK: - Timer control

    /// Start tracking a task. Stops any currently running entry first.
    func startTracking(task: Task, context: ModelContext) {
        if let current = activeEntry {
            current.stop()
        }

        let entry = TimeEntry(task: task)
        context.insert(entry)
        activeEntry = entry

        startDisplayTimer()

        try? context.save()
    }

    /// Stop the currently running entry.
    func stopTracking(context: ModelContext) {
        guard let entry = activeEntry else { return }
        entry.stop()
        activeEntry = nil

        stopDisplayTimer()

        try? context.save()
    }

    /// Switch to a different task (stop current, start new).
    func switchTask(to task: Task, context: ModelContext) {
        startTracking(task: task, context: context)
    }

    // MARK: - Display timer

    private func startDisplayTimer() {
        stopDisplayTimer()
        clockToken = clock.scheduleRepeating(interval: 1.0) { [weak self] in
            self?.tick += 1
        }
    }

    private func stopDisplayTimer() {
        clockToken?.cancel()
        clockToken = nil
    }

    // MARK: - Restore state on launch

    /// Called once at launch to check if there's an unfinished entry
    /// (e.g. app crashed while tracking).
    func restoreActiveEntry(context: ModelContext) {
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: #Predicate<TimeEntry> { $0.endDate == nil }
        )

        if let running = try? context.fetch(descriptor).first {
            activeEntry = running
            startDisplayTimer()
        }
    }
}
