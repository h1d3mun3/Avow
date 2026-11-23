import Testing
@testable import Avow

@Suite("QuickPanelQuery")
struct QuickPanelQueryTests {

    @Test func plainTextHasNoProjectClause() {
        let query = QuickPanelQuery("  review notes ")
        #expect(query.taskText == "review notes")
        #expect(query.projectText == nil)
        #expect(!query.hasProjectClause)
    }

    @Test func splitsOnAt() {
        let query = QuickPanelQuery("review notes @Avow")
        #expect(query.taskText == "review notes")
        #expect(query.projectText == "Avow")
        #expect(query.hasProjectClause)
    }

    @Test func trailingAtIsAnEmptyProjectClause() {
        let query = QuickPanelQuery("review @")
        #expect(query.taskText == "review")
        #expect(query.projectText == "")
        #expect(query.hasProjectClause)
    }

    @Test func theLastAtWins() {
        let query = QuickPanelQuery("a @ b @ c")
        #expect(query.taskText == "a")
        #expect(query.projectText == "c")
    }

    @Test func parsesProjectFacetsAndGroupsInOrder() {
        let query = QuickPanelQuery("review notes @My Project #deep work #meeting +Work")
        #expect(query.taskText == "review notes")
        #expect(query.segments == [
            .init(sigil: .project, text: "My Project"),
            .init(sigil: .facet, text: "deep work"),
            .init(sigil: .facet, text: "meeting"),
            .init(sigil: .group, text: "Work"),
        ])
        #expect(query.activeSegment?.sigil == .group)
    }

    @Test func sigilsInsideWordsAreNotSplits() {
        let query = QuickPanelQuery("learn C++ and mail a@b.com #x")
        #expect(query.taskText == "learn C++ and mail a@b.com")
        #expect(query.segments == [.init(sigil: .facet, text: "x")])
    }

    @Test func completionReplacesTheSegmentBeingTyped() {
        let query = QuickPanelQuery("foo @Avow #re")
        #expect(query.completed(with: "review") == "foo @Avow #review ")
        #expect(QuickPanelQuery("foo @Av").completed(with: "Avow") == "foo @Avow ")
        #expect(QuickPanelQuery("foo").completed(with: "x") == "foo")
    }

    @Test func projectTextKeepsInnerSpaces() {
        #expect(QuickPanelQuery("x @My Project").projectText == "My Project")
    }

    @Test func emptyProjectTextMatchesEverything() {
        #expect(QuickPanelQuery("x @").matches(projectName: "Anything"))
    }

    @Test func projectMatchIsCaseInsensitiveSubstring() {
        let query = QuickPanelQuery("x @vow")
        #expect(query.matches(projectName: "Avow"))
        #expect(!query.matches(projectName: "Other"))
    }

    @Test func sameTaskNameIgnoresCase() {
        let query = QuickPanelQuery(" Review ")
        #expect(query.isSameTaskName("review"))
        #expect(!query.isSameTaskName("review notes"))
    }

    @Test func emptyTaskTextIsNeverTheSameName() {
        #expect(!QuickPanelQuery("").isSameTaskName(""))
    }

    @Test func newProjectNameIsTheTrimmedTextAfterAt() {
        #expect(QuickPanelQuery("x @ New Project ").newProjectName == "New Project")
        #expect(QuickPanelQuery("x @").newProjectName == nil)
        #expect(QuickPanelQuery("x").newProjectName == nil)
    }

    @Test func sameProjectNameIgnoresCaseButNotSubstrings() {
        let query = QuickPanelQuery("x @avow")
        #expect(query.isSameProjectName("Avow"))
        #expect(!query.isSameProjectName("Avow Mobile"))
        #expect(!QuickPanelQuery("x @").isSameProjectName(""))
    }
}
