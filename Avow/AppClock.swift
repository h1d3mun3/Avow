import Foundation

protocol AppClock {
    func now() -> Date
    func scheduleRepeating(interval: TimeInterval, action: @escaping @MainActor () -> Void) -> ClockToken
}

struct ClockToken {
    private let _cancel: () -> Void

    init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }

    func cancel() {
        _cancel()
    }
}

struct SystemClock: AppClock {
    func now() -> Date { .now }

    func scheduleRepeating(interval: TimeInterval, action: @escaping @MainActor () -> Void) -> ClockToken {
        // Timer's block is @Sendable, but this timer is only ever added to the main run loop
        // below, so the callback is always delivered on the main actor.
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return ClockToken { timer.invalidate() }
    }
}
