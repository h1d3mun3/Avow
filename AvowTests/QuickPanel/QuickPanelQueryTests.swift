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

    @Test func onlyTheFirstAtSplits() {
        let query = QuickPanelQuery("a @ b @ c")
        #expect(query.taskText == "a")
        #expect(query.projectText == "b @ c")
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

@Suite("NewTaskTarget")
struct NewTaskTargetTests {
    private func names(_ targets: [NewTaskTarget]) -> [String] {
        targets.map { target in
            switch target {
            case .project(let project): "project:\(project.name)"
            case .newProject(let name): "new:\(name)"
            }
        }
    }

    @Test func withoutAtOnlyTheDefaultProjectIsOffered() {
        let avow = Project(name: "Avow"), other = Project(name: "Other")
        let targets = NewTaskTarget.targets(for: QuickPanelQuery("x"), in: [avow, other], defaultProject: other)
        #expect(names(targets) == ["project:Other"])
    }

    @Test func withoutAtAndNoDefaultNothingIsOffered() {
        #expect(NewTaskTarget.targets(for: QuickPanelQuery("x"), in: [], defaultProject: nil).isEmpty)
    }

    @Test func atListsMatchesThenANewProject() {
        let avow = Project(name: "Avow"), avocado = Project(name: "Avocado"), other = Project(name: "Other")
        let targets = NewTaskTarget.targets(for: QuickPanelQuery("x @av"), in: [avow, avocado, other], defaultProject: nil)
        #expect(names(targets) == ["project:Avow", "project:Avocado", "new:av"])
    }

    @Test func exactMatchSuppressesTheNewProjectOption() {
        let avow = Project(name: "Avow")
        let targets = NewTaskTarget.targets(for: QuickPanelQuery("x @avow"), in: [avow], defaultProject: nil)
        #expect(names(targets) == ["project:Avow"])
    }

    @Test func bareAtListsAllProjectsWithoutANewOne() {
        let a = Project(name: "A"), b = Project(name: "B")
        let targets = NewTaskTarget.targets(for: QuickPanelQuery("x @"), in: [a, b], defaultProject: nil)
        #expect(names(targets) == ["project:A", "project:B"])
    }

    @Test func unknownProjectOffersOnlyANewOne() {
        let targets = NewTaskTarget.targets(for: QuickPanelQuery("x @Zed"), in: [Project(name: "A")], defaultProject: nil)
        #expect(names(targets) == ["new:Zed"])
    }

    @Test func defaultProjectPrefersLastTrackedUnlessArchived() {
        let a = Project(name: "A"), b = Project(name: "B")
        #expect(NewTaskTarget.defaultProject(lastTracked: b, in: [a, b])?.name == "B")
        b.isArchived = true
        #expect(NewTaskTarget.defaultProject(lastTracked: b, in: [a])?.name == "A")
        #expect(NewTaskTarget.defaultProject(lastTracked: nil, in: []) == nil)
    }
}
