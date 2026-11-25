import Testing
@testable import Avow

@Suite("NewTaskPlan")
struct NewTaskPlanTests {
    private let avow = Project(name: "Avow")
    private let other = Project(name: "Other")
    private let review = Facet(name: "review")
    private let work = ProjectGroup(name: "Work")

    private func plans(_ text: String, defaultProject: Project? = nil) -> [NewTaskPlan] {
        NewTaskPlan.plans(
            for: QuickPanelQuery(text),
            context: .init(projects: [avow, other], facets: [review], groups: [work], defaultProject: defaultProject ?? other)
        )
    }

    private func labels(_ plans: [NewTaskPlan]) -> [String] { plans.map { "\($0.title) \($0.summary)" } }

    @Test func plainNameGoesToTheDefaultProject() {
        #expect(labels(plans("foo")) == ["Create \"foo\" in Other"])
    }

    @Test func atListsMatchingProjectsThenANewOne() {
        #expect(labels(plans("foo @av")) == [
            "Create \"foo\" in Avow",
            "Create \"foo\" in new project \"av\"",
        ])
    }

    @Test func exactProjectMatchComesFirstAndSuppressesNew() {
        let result = plans("foo @avow")
        #expect(labels(result) == ["Create \"foo\" in Avow"])
        #expect(result.first?.completion == "Avow")
    }

    @Test func facetSuggestionsKeepTheFinishedProject() {
        #expect(labels(plans("foo @Avow #re")) == [
            "Create \"foo\" in Avow · #review",
            "Create \"foo\" in Avow · #re (new)",
        ])
    }

    @Test func facetWithoutProjectUsesTheDefault() {
        #expect(labels(plans("foo #review")) == ["Create \"foo\" in Other · #review"])
    }

    @Test func finishedFacetsResolveExactOrNewAndStack() {
        #expect(labels(plans("foo #Review #deep +Wo")) == [
            "Create \"foo\" in Other · #review · #deep (new) · +Work",
            "Create \"foo\" in Other · #review · #deep (new) · +Wo (new)",
        ])
    }

    @Test func alreadyUsedFacetIsNotSuggestedAgain() {
        #expect(labels(plans("foo #review #re")) == ["Create \"foo\" in Other · #review · #re (new)"])
    }

    @Test func projectOnlyCreateNeedsANewProjectName() {
        #expect(labels(plans("@Zed")) == ["Create project \"Zed\" "])
        #expect(plans("@avow").isEmpty)
        #expect(plans("@").isEmpty)
        #expect(plans("").isEmpty)
    }

    @Test func projectOnlyWithGroupsIsAllowedForExistingProjects() {
        let result = plans("@Avow +Wo")
        #expect(labels(result) == ["Update project \"Avow\" +Work", "Update project \"Avow\" +Wo (new)"])
        #expect(result.allSatisfy { $0.isProjectOnly })
    }

    @Test func facetsNeedATaskName() {
        #expect(plans("@Avow #re").isEmpty)
        #expect(plans("#re").isEmpty)
    }

    @Test func noDefaultProjectMeansNoPlanWithoutAt() {
        let none = NewTaskPlan.plans(for: QuickPanelQuery("foo"), context: .init(projects: [], facets: [], groups: [], defaultProject: nil))
        #expect(none.isEmpty)
    }

    @Test func defaultProjectPrefersLastTrackedUnlessArchived() {
        #expect(NewTaskTarget.defaultProject(lastTracked: other, in: [avow, other])?.name == "Other")
        other.isArchived = true
        #expect(NewTaskTarget.defaultProject(lastTracked: other, in: [avow])?.name == "Avow")
        #expect(NewTaskTarget.defaultProject(lastTracked: nil, in: []) == nil)
    }
}
