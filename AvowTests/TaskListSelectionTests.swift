import Testing
@testable import Avow

@Suite("TaskListSelection")
struct TaskListSelectionTests {

    @Test func prefersTheRowBelow() {
        #expect(TaskListSelection.neighbor(of: "b", in: ["a", "b", "c"]) == "c")
    }

    @Test func fallsBackToTheRowAboveAtTheEnd() {
        #expect(TaskListSelection.neighbor(of: "c", in: ["a", "b", "c"]) == "b")
    }

    @Test func firstRowMovesDown() {
        #expect(TaskListSelection.neighbor(of: "a", in: ["a", "b"]) == "b")
    }

    @Test func onlyRowLeavesNothingSelected() {
        #expect(TaskListSelection.neighbor(of: "a", in: ["a"]) == nil)
    }

    @Test func unknownRowLeavesNothingSelected() {
        #expect(TaskListSelection.neighbor(of: "z", in: ["a", "b"]) == nil)
    }
}
