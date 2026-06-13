import Foundation

protocol AppClock {
    func now() -> Date
    func scheduleRepeating(interval: TimeInterval, action: @escaping () -> Void) -> ClockToken
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

    func scheduleRepeating(interval: TimeInterval, action: @escaping () -> Void) -> ClockToken {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return ClockToken { timer.invalidate() }
    }
}
