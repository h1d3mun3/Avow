import Foundation
import SwiftData

@Observable
final class AppState {
    /// The currently running time entry, if any.
    var activeEntry: TimeEntry?

    /// Incremented every second while tracking, to trigger SwiftUI updates.
    var tick: UInt64 = 0

    private let clock: any AppClock
    private let timeEntries: any TimeEntryRepository
    private var clockToken: ClockToken?

    var isTracking: Bool {
        activeEntry != nil
    }

    init(clock: any AppClock = SystemClock(), timeEntries: any TimeEntryRepository) {
        self.clock = clock
        self.timeEntries = timeEntries
    }

    // MARK: - Timer control

    /// Start tracking a task. Stops any currently running entry first.
    func startTracking(task: Task) {
        if let current = activeEntry {
            // Fire-and-forget: AppState has no error channel; a persistence failure is intentionally swallowed.
            try? timeEntries.stop(current)
        }

        // Fire-and-forget: AppState has no error channel; a persistence failure is intentionally swallowed.
        activeEntry = try? timeEntries.start(task: task)

        startDisplayTimer()
    }

    /// Stop the currently running entry.
    func stopTracking() {
        guard let entry = activeEntry else { return }
        // Fire-and-forget: AppState has no error channel; a persistence failure is intentionally swallowed.
        try? timeEntries.stop(entry)
        activeEntry = nil

        stopDisplayTimer()
    }

    /// Switch to a different task (stop current, start new).
    func switchTask(to task: Task) {
        startTracking(task: task)
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
    func restoreActiveEntry() {
        if let running = try? timeEntries.fetchRunning() {
            activeEntry = running
            startDisplayTimer()
        }
    }
}
