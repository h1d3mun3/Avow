import Testing
import Foundation
@testable import Avow

@Suite("MinuteRounding")
struct MinuteRoundingTests {

    // MARK: - nearest

    @Test func nearest_roundsDownBelowHalf() {
        #expect(MinuteRounding.nearest(29) == 0)
        #expect(MinuteRounding.nearest(89) == 60)
    }

    @Test func nearest_roundsUpAtOrAboveHalf() {
        #expect(MinuteRounding.nearest(30) == 60)
        #expect(MinuteRounding.nearest(90) == 120)
    }

    @Test func nearest_exactMinutesUnchanged() {
        #expect(MinuteRounding.nearest(0) == 0)
        #expect(MinuteRounding.nearest(60) == 60)
        #expect(MinuteRounding.nearest(3600) == 3600)
    }

    // MARK: - cumulative: the core guarantee

    /// The user's example: 20 min + 40 min must total exactly 60 — never 59 or 61.
    @Test func cumulative_twentyPlusFortyIsExactlySixty() {
        let parts = MinuteRounding.cumulative([20 * 60, 40 * 60])
        #expect(parts == [20 * 60, 40 * 60])
        #expect(parts.reduce(0, +) == 60 * 60)
    }

    /// Sub-minute fragments that would each round to 0 independently still sum to the
    /// rounded total (3 × 40s = 2:00 → parts 1,0,1 = 2 min).
    @Test func cumulative_fragmentsSumToRoundedTotal() {
        let parts = MinuteRounding.cumulative([40, 40, 40])
        #expect(parts.reduce(0, +) == 120)
        #expect(parts.allSatisfy { $0.truncatingRemainder(dividingBy: 60) == 0 })
    }

    /// Independent rounding would give 21 + 41 = 62; cumulative keeps it at 61.
    @Test func cumulative_doesNotOvershootTheTotal() {
        let parts = MinuteRounding.cumulative([20 * 60 + 30, 40 * 60 + 40])
        #expect(parts.reduce(0, +) == MinuteRounding.nearest(20 * 60 + 30 + 40 * 60 + 40))
        #expect(parts.reduce(0, +) == 61 * 60)
    }

    // MARK: - cumulative: invariants over many shapes

    @Test(arguments: [
        [Double]([]),
        [0],
        [10, 20, 30],
        [59, 1, 59, 1],
        [90, 90, 90, 90],
        [3599, 1, 30, 29, 1000, 5],
        [25, 25, 25, 25, 25, 25],
    ])
    func cumulative_partsAlwaysSumToNearestTotal(_ durations: [Double]) {
        let parts = MinuteRounding.cumulative(durations)
        let grandTotal = durations.reduce(0, +)
        // Parts reconcile to the rounded whole.
        #expect(parts.reduce(0, +) == MinuteRounding.nearest(grandTotal))
        // Every displayed part is a whole minute and non-negative.
        #expect(parts.allSatisfy { $0 >= 0 && $0.truncatingRemainder(dividingBy: 60) == 0 })
        // One value per input.
        #expect(parts.count == durations.count)
    }

    /// The documented guarantee: the displayed running total never drifts more than
    /// 30 seconds from reality — at *every* prefix, not just the grand total.
    @Test(arguments: [
        [Double]([]),
        [0],
        [10, 20, 30],
        [59, 1, 59, 1],
        [90, 90, 90, 90],
        [3599, 1, 30, 29, 1000, 5],
        [25, 25, 25, 25, 25, 25],
    ])
    func cumulative_runningTotalStaysWithin30sOfReality(_ durations: [Double]) {
        let parts = MinuteRounding.cumulative(durations)
        var rawSoFar: TimeInterval = 0
        var shownSoFar: TimeInterval = 0
        for (raw, shown) in zip(durations, parts) {
            rawSoFar += raw
            shownSoFar += shown
            #expect(abs(shownSoFar - rawSoFar) <= MinuteRounding.minute / 2)
        }
    }

    // MARK: - cumulative: the documented trade-off

    /// An item's rounded value depends on its position in the list — the same
    /// multiset in a different order distributes the minutes differently, even
    /// though the total is identical. Pinned so this intended behaviour can't drift
    /// silently.
    @Test func cumulative_dependsOnOrder() {
        let a = MinuteRounding.cumulative([50, 20, 50])
        let b = MinuteRounding.cumulative([20, 50, 50])
        #expect(a == [60, 0, 60])
        #expect(b == [0, 60, 60])
        #expect(a.reduce(0, +) == b.reduce(0, +))
    }
}
