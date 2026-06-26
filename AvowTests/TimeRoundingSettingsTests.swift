import Testing
import Foundation
@testable import Avow

@MainActor
@Suite("TimeRoundingSettings")
struct TimeRoundingSettingsTests {

    /// A fresh, isolated defaults store per call so tests never see each other's
    /// writes or touch the shared `.standard` suite.
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "TimeRoundingSettingsTests.\(UUID().uuidString)")!
    }

    // MARK: - Default state

    /// The whole feature ships dark: existing installs must keep full-precision
    /// display until the user opts in.
    @Test func defaultsToOff() {
        let settings = TimeRoundingSettings(defaults: isolatedDefaults())
        #expect(settings.roundToMinute == false)
    }

    // MARK: - Off is a passthrough (guards existing behaviour)

    @Test func offReturnsStandaloneDurationUnchanged() {
        let settings = TimeRoundingSettings(defaults: isolatedDefaults())
        #expect(settings.display(20 * 60 + 29) == 20 * 60 + 29)
    }

    @Test func offReturnsListUnchanged() {
        let settings = TimeRoundingSettings(defaults: isolatedDefaults())
        let raw: [TimeInterval] = [20 * 60 + 29, 40 * 60 + 31]
        #expect(settings.display(raw) == raw)
    }

    // MARK: - On dispatches to the right rounding

    @Test func onRoundsStandaloneToNearestMinute() {
        let settings = TimeRoundingSettings(defaults: isolatedDefaults())
        settings.roundToMinute = true
        #expect(settings.display(20 * 60 + 29) == 20 * 60)
        #expect(settings.display(20 * 60 + 30) == 21 * 60)
    }

    /// On a list it must use *cumulative* rounding, so the parts still sum to the
    /// rounded total — this is the whole reason the feature exists.
    @Test func onRoundsListCumulativelySoPartsSumToTotal() {
        let settings = TimeRoundingSettings(defaults: isolatedDefaults())
        settings.roundToMinute = true
        let parts = settings.display([20 * 60, 40 * 60])
        #expect(parts == [20 * 60, 40 * 60])
        #expect(parts.reduce(0, +) == 60 * 60)
    }

    // MARK: - Persistence

    @Test func enablingPersistsAcrossInstances() {
        let defaults = isolatedDefaults()
        TimeRoundingSettings(defaults: defaults).roundToMinute = true

        let reloaded = TimeRoundingSettings(defaults: defaults)
        #expect(reloaded.roundToMinute == true)
    }

    @Test func togglingBackOffPersists() {
        let defaults = isolatedDefaults()
        let settings = TimeRoundingSettings(defaults: defaults)
        settings.roundToMinute = true
        settings.roundToMinute = false

        #expect(TimeRoundingSettings(defaults: defaults).roundToMinute == false)
    }

    @Test func separateStoresDoNotLeak() {
        let a = TimeRoundingSettings(defaults: isolatedDefaults())
        a.roundToMinute = true

        let b = TimeRoundingSettings(defaults: isolatedDefaults())
        #expect(b.roundToMinute == false)
    }
}
