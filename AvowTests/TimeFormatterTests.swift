import Testing
@testable import Avow

@Suite("TimeInterval+TimeFormatter")
struct TimeFormatterTests {

    // MARK: - timerFormatted

    @Test func timerFormatted_zero() {
        #expect((0.0).timerFormatted == "0:00:00")
    }

    @Test func timerFormatted_subMinute() {
        #expect((59.0).timerFormatted == "0:00:59")
    }

    @Test func timerFormatted_exactlyOneMinute() {
        #expect((60.0).timerFormatted == "0:01:00")
    }

    @Test func timerFormatted_mixedMinutesAndSeconds() {
        #expect((90.0).timerFormatted == "0:01:30")
    }

    @Test func timerFormatted_justUnderOneHour() {
        #expect((3599.0).timerFormatted == "0:59:59")
    }

    @Test func timerFormatted_exactlyOneHour() {
        #expect((3600.0).timerFormatted == "1:00:00")
    }

    @Test func timerFormatted_mixedHoursMinutesSeconds() {
        #expect((3661.0).timerFormatted == "1:01:01")
    }

    @Test func timerFormatted_largeValue() {
        #expect((36000.0).timerFormatted == "10:00:00")
    }

    // MARK: - shortFormatted

    @Test func shortFormatted_zero() {
        #expect((0.0).shortFormatted == "0:00")
    }

    @Test func shortFormatted_subMinute_roundsDown() {
        #expect((59.0).shortFormatted == "0:00")
    }

    @Test func shortFormatted_exactlyOneMinute() {
        #expect((60.0).shortFormatted == "0:01")
    }

    @Test func shortFormatted_justUnderOneHour() {
        #expect((3599.0).shortFormatted == "0:59")
    }

    @Test func shortFormatted_exactlyOneHour() {
        #expect((3600.0).shortFormatted == "1:00")
    }

    @Test func shortFormatted_mixedHoursAndMinutes() {
        #expect((5400.0).shortFormatted == "1:30")
    }

    @Test func shortFormatted_largeValue() {
        #expect((36000.0).shortFormatted == "10:00")
    }
}
