import Testing
@testable import Avow

@Suite("QuickPanelSelection")
struct QuickPanelSelectionTests {

    @Test func movingDownAdvances() {
        #expect(QuickPanelSelection.moved(from: 0, by: 1, count: 3) == 1)
    }

    @Test func movingUpDecrements() {
        #expect(QuickPanelSelection.moved(from: 2, by: -1, count: 3) == 1)
    }

    @Test func clampsAtTop() {
        #expect(QuickPanelSelection.moved(from: 0, by: -1, count: 3) == 0)
    }

    @Test func clampsAtBottom() {
        #expect(QuickPanelSelection.moved(from: 2, by: 1, count: 3) == 2)
    }

    @Test func emptyListStaysZero() {
        #expect(QuickPanelSelection.moved(from: 0, by: 1, count: 0) == 0)
        #expect(QuickPanelSelection.moved(from: 0, by: -1, count: 0) == 0)
    }
}
