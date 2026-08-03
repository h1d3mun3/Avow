import Foundation
import SwiftData

@Observable
final class AppState {
    /// The currently running time entry, if any.
    var activeEntry: TimeEntry?

    /// Incremented every second while tracking, to trigger SwiftUI updates.
    var tick: UInt64 = 0

    /// Fired synchronously whenever `activeEntry` changes (start, stop, switch, restore). Lets
    /// non-SwiftUI observers (MenuBarStatusController's AppKit-driven status item) refresh
    /// immediately instead of waiting for their own poll interval.
    var onActiveEntryChange: (() -> Void)?

    /// Fired synchronously on the same 1s timer tick that increments `tick`. Lets non-SwiftUI
    /// observers stay in lockstep with the SwiftUI views that read `liveDuration` instead of
    /// running their own, independently-phased poll timer (which would visibly drift out of sync
    /// with the SwiftUI-rendered clocks by up to ~1s).
    var onTick: (() -> Void)?

    private let clock: any AppClock
    private let timeEntries: any TimeEntryRepository
    private var clockToken: ClockToken?

    var isTracking: Bool {
        activeEntry != nil
    }

    /// Reads `tick` so SwiftUI re-renders every second while tracking, then returns the entry's current duration.
    func liveDuration(of entry: TimeEntry) -> TimeInterval {
        _ = tick
        return entry.duration
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
        onActiveEntryChange?()
    }

    /// Stop the currently running entry.
    func stopTracking() {
        guard let entry = activeEntry else { return }
        // Fire-and-forget: AppState has no error channel; a persistence failure is intentionally swallowed.
        try? timeEntries.stop(entry)
        activeEntry = nil

        stopDisplayTimer()
        onActiveEntryChange?()
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
            self?.onTick?()
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
            onActiveEntryChange?()
        }
    }
}
